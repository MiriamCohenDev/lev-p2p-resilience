import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lev/core/db/app_database.dart';
import 'package:lev/features/chat/data/drift_chat_repository.dart';
import 'package:lev/features/chat/domain/message.dart';

/// These run against an **unencrypted in-memory** database, on purpose.
///
/// What is under test here is queries, mapping and streams. That the file on
/// disk is encrypted is proven by `test/core/db/encrypted_database_test.dart`
/// and by the on-device tests in `integration_test/`; paying the cipher's cost
/// in every repository test would be measuring the same thing a third time.
///
/// The one thing that must be reproduced from the real opener is
/// `PRAGMA foreign_keys` — otherwise the orphan test below would pass for the
/// wrong reason.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late DriftChatRepository repository;

  setUp(() {
    database = AppDatabase(
      NativeDatabase.memory(
        setup: (db) => db.execute('PRAGMA foreign_keys = ON;'),
      ),
    );
    repository = DriftChatRepository(database.chatDao);
  });

  tearDown(() => database.close());

  Message userMessage(String conversationId, String text, DateTime at) =>
      Message.fromUserInput(
        conversationId: conversationId,
        text: text,
        createdAt: at,
      );

  group('createConversation', () {
    test('assigns a UUID and matching timestamps', () async {
      final conversation = await repository.createConversation(title: 'first');

      expect(conversation.id, hasLength(36));
      expect(conversation.title, 'first');
      // A conversation that has never been spoken in was last active when it
      // was created.
      expect(conversation.updatedAt, conversation.createdAt);
    });

    test('gives every conversation a distinct id', () async {
      final a = await repository.createConversation();
      final b = await repository.createConversation();

      expect(a.id, isNot(b.id));
    });

    test('is visible through watchConversations', () async {
      final created = await repository.createConversation(title: 'visible');

      expect(await repository.watchConversations().first, [created]);
    });
  });

  group('messages', () {
    test('come back oldest first, whatever order they went in', () async {
      final conversation = await repository.createConversation();
      final base = DateTime.utc(2026, 8, 24, 10);

      await repository.append(userMessage(conversation.id, 'third', base));
      await repository.append(
        userMessage(
          conversation.id,
          'first',
          base.subtract(const Duration(minutes: 2)),
        ),
      );
      await repository.append(
        userMessage(
          conversation.id,
          'second',
          base.subtract(const Duration(minutes: 1)),
        ),
      );

      final messages = await repository.watchMessages(conversation.id).first;
      expect(
        messages.map((m) => m.text),
        ['first', 'second', 'third'],
      );
    });

    test('round-trip preserves every field', () async {
      final conversation = await repository.createConversation();
      final sent = Message.fromAssistant(
        conversationId: conversation.id,
        text: 'a reply',
        createdAt: DateTime.utc(2026, 8, 24, 11),
      );

      await repository.append(sent);

      final stored =
          (await repository.watchMessages(conversation.id).first).single;
      expect(stored.id, sent.id);
      expect(stored.text, 'a reply');
      expect(stored.fromUser, isFalse);
      expect(stored.createdAt.isAtSameMomentAs(sent.createdAt), isTrue);
    });

    test('are scoped to their own conversation', () async {
      final mine = await repository.createConversation(title: 'mine');
      final other = await repository.createConversation(title: 'other');
      final at = DateTime.utc(2026, 8, 24, 12);

      await repository.append(userMessage(mine.id, 'in mine', at));
      await repository.append(userMessage(other.id, 'in other', at));

      final messages = await repository.watchMessages(mine.id).first;
      expect(messages.map((m) => m.text), ['in mine']);
    });

    test('the stream re-emits on every append', () async {
      final conversation = await repository.createConversation();
      final stream = repository.watchMessages(conversation.id);
      final at = DateTime.utc(2026, 8, 24, 13);

      // The first event is the empty conversation; each append adds one.
      final seen = expectLater(
        stream.map((messages) => messages.length),
        emitsInOrder(<int>[0, 1, 2]),
      );

      await repository.append(userMessage(conversation.id, 'one', at));
      await repository.append(
        userMessage(conversation.id, 'two', at.add(const Duration(minutes: 1))),
      );

      await seen;
    });

    test('an orphan message is rejected by the foreign key', () async {
      await expectLater(
        repository.append(
          userMessage('no-such-conversation', 'orphan', DateTime.utc(2026)),
        ),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  group('append', () {
    test('moves the conversation to the top of the list', () async {
      final quiet = await repository.createConversation(title: 'quiet');
      final busy = await repository.createConversation(title: 'busy');
      final at = DateTime.utc(2026, 8, 24, 14);

      // Explicit timestamps rather than creation order: the point is that
      // `updatedAt` drives the ordering, and two conversations created
      // back-to-back are a coin toss otherwise.
      await repository.append(userMessage(quiet.id, 'once', at));
      await repository.append(
        userMessage(busy.id, 'later', at.add(const Duration(minutes: 5))),
      );

      expect(
        (await repository.watchConversations().first).map((c) => c.title),
        ['busy', 'quiet'],
      );

      await repository.append(
        userMessage(
          quiet.id,
          'last word',
          at.add(const Duration(minutes: 10)),
        ),
      );

      expect(
        (await repository.watchConversations().first).map((c) => c.title),
        ['quiet', 'busy'],
      );
    });

    test('sets updatedAt from the message, not from the clock', () async {
      final conversation = await repository.createConversation();
      final at = DateTime.utc(2026, 8, 24, 15);

      await repository.append(userMessage(conversation.id, 'hello', at));

      final stored = (await repository.watchConversations().first).single;
      expect(stored.updatedAt.isAtSameMomentAs(at), isTrue);
      // createdAt is untouched by the append.
      expect(
        stored.createdAt.isAtSameMomentAs(conversation.createdAt),
        isTrue,
      );
    });

    test('leaves the conversation intact if the insert fails', () async {
      final conversation = await repository.createConversation();
      final at = DateTime.utc(2026, 8, 24, 16);
      final message = userMessage(conversation.id, 'once', at);

      await repository.append(message);

      // Same id again: the insert fails, and the transaction must roll the
      // updatedAt bump back with it.
      await expectLater(
        repository.append(
          Message(
            id: message.id,
            conversationId: conversation.id,
            text: 'twice',
            fromUser: true,
            createdAt: at.add(const Duration(hours: 1)),
          ),
        ),
        throwsA(isA<SqliteException>()),
      );

      final stored = (await repository.watchConversations().first).single;
      expect(stored.updatedAt.isAtSameMomentAs(at), isTrue);
      expect(
        (await repository.watchMessages(conversation.id).first).single.text,
        'once',
      );
    });
  });

  test('deleting a conversation takes its messages with it', () async {
    final conversation = await repository.createConversation();
    await repository.append(
      userMessage(conversation.id, 'goes away', DateTime.utc(2026, 8, 24, 17)),
    );

    await database.chatDao.deleteConversation(conversation.id);

    expect(await repository.watchConversations().first, isEmpty);
    expect(await repository.watchMessages(conversation.id).first, isEmpty);
  });
}
