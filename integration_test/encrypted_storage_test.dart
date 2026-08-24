// Runs the encrypted-storage path on a real device, against the real OS secure
// store and the real database file:
//
//   flutter test integration_test -d emulator-5554
//   flutter test integration_test -d windows
//
// Everything under test/ substitutes the secure store (`InMemoryKeyStore`) or
// the key manager (`FakeKeyManager`), because a host test has no platform
// channels. That leaves the most consequential link — Android Keystore /
// wincred actually handing back the same KEK on a later launch — unproven. This
// is the file that proves it, and it is why technical-spec §9's Phase 1
// done-criteria names Android *and* desktop.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lev/core/crypto/kek_source.dart';
import 'package:lev/core/db/plaintext_audit.dart';
import 'package:lev/core/di/chat_providers.dart';
import 'package:lev/core/di/crypto_providers.dart';
import 'package:lev/core/di/db_providers.dart';
import 'package:lev/features/chat/domain/message.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// A container wired exactly as the app wires itself — nothing overridden.
  /// Each one stands in for a fresh launch.
  ProviderContainer launch() => ProviderContainer();

  Future<File> databaseFile(ProviderContainer container) =>
      container.read(appDatabaseFileProvider.future);

  // Cleans up *before* each test rather than after, for two reasons: every test
  // starts from a known-empty database, and the last one leaves its file on the
  // device so it can be pulled with `adb` and inspected by hand.
  //
  // The database file only. The KEK and the key record stay: deleting key
  // material is the one thing this whole module refuses to do, and a test is not
  // going to be the exception that does it.
  setUp(() async {
    final container = launch();
    final file = await databaseFile(container);
    for (final sibling in file.parent.listSync().whereType<File>()) {
      if (sibling.path.startsWith(file.path)) sibling.deleteSync();
    }
    container.dispose();
  });

  testWidgets('the DEK survives in the OS secure store across launches',
      (tester) async {
    final first = launch();
    final firstDek = await first.read(keyManagerProvider).obtainDek();
    expect(firstDek, hasLength(32));
    first.dispose();

    // A new container re-reads and re-unwraps from scratch, so matching bytes
    // can only mean the KEK really round-tripped through the OS store. This is
    // the failure technical-decisions #12 exists to prevent: silently
    // provisioning a *new* DEK would orphan an existing encrypted database.
    final second = launch();
    final keyManager = second.read(keyManagerProvider);
    expect(await keyManager.obtainDek(), orderedEquals(firstDek));
    expect(await keyManager.currentMode(), KeyWrappingMode.secureStorage);
    second.dispose();
  });

  testWidgets('a conversation survives a close and reopen', (tester) async {
    final sentAt = DateTime.now();

    final first = launch();
    final repository = await first.read(chatRepositoryProvider.future);
    final conversation = await repository.createConversation(title: 'on device');
    await repository.append(
      Message.fromUserInput(
        conversationId: conversation.id,
        text: 'device round trip $storageProbeCanary',
        createdAt: sentAt,
      ),
    );
    // Disposing the container closes the database through its onDispose.
    first.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final second = launch();
    final reopened = await second.read(chatRepositoryProvider.future);
    final conversations = await reopened.watchConversations().first;
    final messages = await reopened.watchMessages(conversation.id).first;
    final path = (await databaseFile(second)).path;
    second.dispose();

    expect(conversations, hasLength(1));
    expect(conversations.single.title, 'on device');
    expect(messages, hasLength(1));
    expect(messages.single.text, contains(storageProbeCanary));
    expect(messages.single.fromUser, isTrue);
    expect(messages.single.createdAt.isAtSameMomentAs(sentAt), isTrue);

    // The path is printed, never the key — it is what the manual adb / byte
    // checks operate on.
    debugPrint('application database: $path');
  });

  testWidgets('the file on the device holds no plaintext', (tester) async {
    final container = launch();
    final repository = await container.read(chatRepositoryProvider.future);
    final conversation = await repository.createConversation(title: 'secret');
    await repository.append(
      Message.fromUserInput(
        conversationId: conversation.id,
        text: 'sensitive $storageProbeCanary payload',
      ),
    );
    final file = await databaseFile(container);
    container.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(file.existsSync(), isTrue);
    // A zero-byte file would pass every byte check vacuously — see the lesson
    // recorded in technical-decisions #13.
    expect(file.lengthSync(), greaterThan(0));
    // Same detector the host tests and tool/probe_encrypted_db.dart use, now
    // pointed at what the device actually wrote.
    expect(plaintextComplaints(file.parent), isEmpty);
  });
}
