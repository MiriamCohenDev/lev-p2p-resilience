import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lev/core/db/app_database.dart';
import 'package:path/path.dart' as p;

/// Schema 1 → 2: the `preferences` table arrives, and nothing already stored is
/// disturbed (technical-decisions #23).
///
/// The v1 database is built from raw DDL rather than from `drift_dev schema
/// generate`'s helpers. Those helpers name each field after its column, and
/// `messages.text` collides with drift's own `Table.text` builder — the reason
/// `Messages.body` is declared with `named('text')` in the first place — so the
/// generated snapshot does not compile. The DDL below is the schema
/// `drift_schemas/drift_schema_v1.json` describes, column for column.
const String _schemaV1 = '''
CREATE TABLE conversations (
  id TEXT NOT NULL PRIMARY KEY,
  title TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  summary TEXT NULL,
  summary_up_to_message_id TEXT NULL,
  system_prompt_version TEXT NULL,
  model_id TEXT NULL,
  is_deleted INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE messages (
  id TEXT NOT NULL PRIMARY KEY,
  conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  text TEXT NOT NULL,
  role TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE INDEX messages_conversation_created
  ON messages (conversation_id, created_at);
''';

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    directory = await Directory.systemTemp.createTemp('lev-migration');
    file = File(p.join(directory.path, 'lev.db'));
  });

  tearDown(() => directory.delete(recursive: true));

  /// Writes a database at schema 1 holding one conversation and one message.
  Future<void> seedVersion1() async {
    final raw = NativeDatabase(file);
    final db = _RawDatabase(raw);
    for (final statement in _schemaV1.split(';')) {
      if (statement.trim().isEmpty) continue;
      await db.customStatement(statement);
    }
    await db.customStatement('PRAGMA user_version = 1;');
    await db.customStatement(
      "INSERT INTO conversations (id, title, created_at, updated_at) "
      "VALUES ('c1', 'before the migration', "
      "'2026-08-30T10:00:00.000', '2026-08-30T10:00:00.000');",
    );
    await db.customStatement(
      "INSERT INTO messages (id, conversation_id, text, role, created_at) "
      "VALUES ('m1', 'c1', 'said before', 'user', '2026-08-30T10:00:00.000');",
    );
    await db.close();
  }

  test('upgrading from 1 adds preferences and keeps the conversation',
      () async {
    await seedVersion1();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);

    // Forces the migration: drift opens lazily.
    final conversations = await upgraded.select(upgraded.conversations).get();

    expect(conversations, hasLength(1));
    expect(conversations.single.title, 'before the migration');

    final messages = await upgraded.select(upgraded.messages).get();
    expect(messages.single.body, 'said before');

    // The new table exists and is usable.
    await upgraded.preferencesDao.write('ui.appearance', 'dark');
    expect(await upgraded.preferencesDao.read('ui.appearance'), 'dark');

    final version = await upgraded
        .customSelect('PRAGMA user_version;')
        .getSingle();
    expect(version.data.values.single, 2);
  });

  test('a fresh database is created at 2 with both tables', () async {
    final database = AppDatabase(NativeDatabase(file));
    addTearDown(database.close);

    await database.preferencesDao.write('ui.languageCode', 'he');
    expect(await database.preferencesDao.read('ui.languageCode'), 'he');
    expect(await database.select(database.conversations).get(), isEmpty);
  });

  test('foreign keys are still enforced after a migration', () async {
    await seedVersion1();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);

    // `beforeOpen` re-applies `PRAGMA foreign_keys` because a migration opens
    // its own connection. Without it the `references` declaration would be a
    // comment, and an orphaned message would be accepted silently.
    await expectLater(
      upgraded.customStatement(
        "INSERT INTO messages (id, conversation_id, text, role, created_at) "
        "VALUES ('m2', 'ghost', 'orphan', 'user', '2026-08-30T11:00:00.000');",
      ),
      throwsA(isA<Exception>()),
    );
  });
}

/// A bare drift wrapper, used only to run DDL against a file.
class _RawDatabase extends GeneratedDatabase {
  _RawDatabase(super.executor);

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  int get schemaVersion => 1;
}
