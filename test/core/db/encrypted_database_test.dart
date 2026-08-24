import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lev/core/crypto/crypto_errors.dart';
import 'package:lev/core/db/app_database.dart';
import 'package:lev/core/db/database_errors.dart';
import 'package:lev/core/db/encrypted_database_opener.dart';
import 'package:lev/core/db/plaintext_audit.dart';
import 'package:lev/features/chat/data/drift_chat_repository.dart';
import 'package:lev/features/chat/domain/message.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'fake_key_manager.dart';

void main() {
  // Several tests deliberately open the same file twice to prove that data
  // survives a close, which is exactly the shape drift warns about.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory directory;
  late File file;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('lev_db_test');
    file = File(p.join(directory.path, 'lev.db'));
  });

  tearDown(() => directory.deleteSync(recursive: true));

  Future<AppDatabase> open(Uint8List dek) async {
    return AppDatabase(
      await openEncryptedDatabase(
        keyManager: FakeKeyManager.withDek(dek),
        file: file,
      ),
    );
  }

  /// Writes [text] as a real message in a real conversation, so what the file
  /// holds is user data in the shape the app stores it.
  Future<void> write(AppDatabase db, String text) async {
    final repository = DriftChatRepository(db.chatDao);
    final conversation = await repository.createConversation(title: 'probe');
    await repository.append(
      Message.fromUserInput(
        conversationId: conversation.id,
        text: text,
        createdAt: DateTime.utc(2026, 8, 23, 12),
      ),
    );
  }

  group('encrypted database', () {
    test('writes and reads back across a close and reopen', () async {
      final first = await open(fakeDek(0));
      await write(first, 'first value $storageProbeCanary');
      await first.close();

      final second = await open(fakeDek(0));
      final rows = await second.select(second.messages).get();
      await second.close();

      expect(rows, hasLength(1));
      expect(rows.single.body, contains(storageProbeCanary));
      expect(rows.single.fromUser, isTrue);
      // drift stores a DateTime as unix seconds and hands it back in local
      // time, so compare the instant rather than the representation.
      expect(
        rows.single.createdAt.isAtSameMomentAs(DateTime.utc(2026, 8, 23, 12)),
        isTrue,
      );
    });

    test('leaves no plaintext on disk', () async {
      final db = await open(fakeDek(0));
      await write(db, 'sensitive $storageProbeCanary payload');
      await db.close();

      expect(plaintextComplaints(directory), isEmpty);
    });

    // Control. Both assertions above would also pass on an empty directory or a
    // truncated file, so on their own they prove very little. SQLCipher only
    // encrypts a connection that was keyed — open one without `PRAGMA key` and
    // it writes an ordinary plaintext SQLite file. That file is what the
    // detectors must catch, and this is what stops the test above from being
    // vacuous.
    test('the plaintext detectors fire on an unencrypted file', () {
      final unkeyed = sqlite3.open(file.path);
      unkeyed
        ..execute('CREATE TABLE messages (id TEXT, text TEXT);')
        ..execute(
          'INSERT INTO messages VALUES (?, ?);',
          ['m1', 'sensitive $storageProbeCanary payload'],
        );
      unkeyed.close();

      expect(
        plaintextComplaints(directory),
        containsAll([
          contains('plain SQLite header'),
          contains('in plaintext'),
        ]),
      );
    });

    test('refuses to open with the wrong key', () async {
      final first = await open(fakeDek(0));
      await write(first, storageProbeCanary);
      await first.close();

      final second = await open(fakeDek(1));
      await expectLater(
        second.select(second.messages).get(),
        throwsA(isA<DatabaseKeyLost>()),
      );
      await second.close();
    });

    test('enforces the message -> conversation foreign key', () async {
      // Proves `PRAGMA foreign_keys = ON` is actually applied by the opener:
      // without it SQLite accepts the orphan silently.
      final db = await open(fakeDek(0));
      await expectLater(
        DriftChatRepository(db.chatDao).append(
          Message.fromUserInput(
            conversationId: 'no-such-conversation',
            text: 'orphan',
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
      await db.close();
    });
  });

  group('when obtainDek fails', () {
    test('a transient store failure creates no database file', () async {
      await expectLater(
        openEncryptedDatabase(
          keyManager: FakeKeyManager.failing(
            const KeyStoreUnavailable('read failed (test)'),
          ),
          file: file,
        ),
        throwsA(
          isA<DatabaseKeyUnavailable>()
              .having((e) => e.cause, 'cause', isA<KeyStoreUnavailable>()),
        ),
      );

      expect(file.existsSync(), isFalse);
      expect(directory.listSync(), isEmpty);
    });

    test('a lost KEK leaves an existing database untouched', () async {
      final existing = await open(fakeDek(0));
      await write(existing, storageProbeCanary);
      await existing.close();
      final before = file.readAsBytesSync();

      await expectLater(
        openEncryptedDatabase(
          keyManager: FakeKeyManager.failing(
            const KeyMaterialMissing(MissingKeyMaterial.kek, 'gone (test)'),
          ),
          file: file,
        ),
        throwsA(
          isA<DatabaseKeyLost>()
              .having((e) => e.databaseFileExists, 'databaseFileExists', isTrue),
        ),
      );

      expect(file.readAsBytesSync(), orderedEquals(before));
    });

    test('a lost key record reports whether anything was at stake', () async {
      const missing = KeyMaterialMissing(
        MissingKeyMaterial.wrappedDek,
        'record gone (test)',
      );

      // No database file: this installation could be reset safely — though
      // resetting is deliberately left to a layer that can ask the user.
      await expectLater(
        openEncryptedDatabase(
          keyManager: FakeKeyManager.failing(missing),
          file: file,
        ),
        throwsA(
          isA<DatabaseKeyLost>().having(
            (e) => e.databaseFileExists,
            'databaseFileExists',
            isFalse,
          ),
        ),
      );
      expect(file.existsSync(), isFalse);

      // With a file present the same key state means unrecoverable data.
      file.writeAsBytesSync(List.filled(64, 7));
      await expectLater(
        openEncryptedDatabase(
          keyManager: FakeKeyManager.failing(missing),
          file: file,
        ),
        throwsA(
          isA<DatabaseKeyLost>().having(
            (e) => e.databaseFileExists,
            'databaseFileExists',
            isTrue,
          ),
        ),
      );
      expect(file.lengthSync(), 64);
    });
  });
}
