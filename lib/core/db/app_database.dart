import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// A conversation with the assistant (technical-spec §6.1).
///
/// No `originDeviceId` and no `isDeleted`. CLAUDE.md's UUID / timestamp /
/// tombstone rule governs **shareable** entities, and chat is not one: §3.1
/// gives it zero dependency on networking and §2.2 puts sync out of scope. §6.1
/// lists these columns and no others. See technical-decisions #14.
///
/// The row class is named `ConversationRow`, not `Conversation`: the domain
/// entity in `features/chat/domain` owns that name, and the two meet in the
/// repository implementation.
@DataClassName('ConversationRow')
class Conversations extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  DateTimeColumn get createdAt => dateTime()();

  /// Bumped whenever a message is appended, so the conversation list can be
  /// ordered by recent activity rather than by creation.
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One message in a conversation — from the user or from the assistant
/// (technical-spec §6.1).
@DataClassName('MessageRow')
class Messages extends Table {
  TextColumn get id => text()();

  /// Enforced, not merely documented: `PRAGMA foreign_keys = ON` is set on every
  /// connection in `encrypted_database_opener.dart`.
  TextColumn get conversationId =>
      text().references(Conversations, #id, onDelete: KeyAction.cascade)();

  /// §6.1 calls this field `text`, and `named` keeps that as the column name on
  /// disk. The Dart getter cannot be `text`: that is drift's own column-builder
  /// method on [Table]. The domain entity restores the spec's name.
  TextColumn get body => text().named('text')();

  BoolColumn get fromUser => boolean()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The application database: `lev.db`, opened through SQLCipher.
///
/// Chat only, at `schemaVersion 1`. The mutual-aid tables (`HelpRequest`,
/// `HelpCommitment` — §6.1) arrive as schema **2** in Phase 4; that is what the
/// explicit [migration] below exists to make obvious, even though `onCreate`
/// currently does exactly what drift would default to.
@DriftDatabase(tables: [Conversations, Messages], daos: [ChatDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  /// Timestamps are stored as ISO-8601 **text**, not as unix seconds.
  ///
  /// Drift's default truncates to whole seconds, and that is not good enough
  /// here: in a streaming chat a user's message and the assistant's reply can
  /// land in the same second, and `ORDER BY createdAt` would then put them in an
  /// arbitrary order that changes between reads. Text keeps sub-second precision
  /// and sorts correctly as a string. Chosen now, at schemaVersion 1, because
  /// changing it later would mean rewriting every stored timestamp.
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        // onUpgrade lands here with the Phase 4 tables. `drift_schemas/` holds a
        // dump of this version so that migration can be tested rather than
        // hoped about.
      );
}

/// The chat queries. Returns drift rows; turning them into domain entities is
/// the job of `features/chat/data` (technical-spec §3.4 puts DAOs here, and
/// §3.2 keeps the domain free of drift).
@DriftAccessor(tables: [Conversations, Messages])
class ChatDao extends DatabaseAccessor<AppDatabase> with _$ChatDaoMixin {
  ChatDao(super.db);

  /// Most recently active first.
  Stream<List<ConversationRow>> watchConversations() {
    return (select(conversations)
          ..orderBy([(c) => OrderingTerm.desc(c.updatedAt)]))
        .watch();
  }

  Future<void> insertConversation(ConversationsCompanion conversation) {
    return into(conversations).insert(conversation);
  }

  /// Oldest first — reading order.
  Stream<List<MessageRow>> watchMessages(String conversationId) {
    return (select(messages)
          ..where((m) => m.conversationId.equals(conversationId))
          ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
        .watch();
  }

  /// Inserts [message] and marks its conversation as active, as one unit.
  ///
  /// The two must not come apart: a message whose conversation still claims an
  /// older `updatedAt` would sort wrongly in the list forever after.
  Future<void> appendMessage(MessagesCompanion message, DateTime at) {
    return transaction(() async {
      await into(messages).insert(message);
      await (update(conversations)
            ..where((c) => c.id.equals(message.conversationId.value)))
          .write(ConversationsCompanion(updatedAt: Value(at)));
    });
  }

  Future<void> deleteConversation(String id) {
    // Messages go with it through the cascade on the foreign key.
    return (delete(conversations)..where((c) => c.id.equals(id))).go();
  }
}
