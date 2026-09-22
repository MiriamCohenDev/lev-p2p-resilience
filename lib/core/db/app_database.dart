import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// A conversation with the assistant (technical-spec §6.1).
///
/// No `originDeviceId`. CLAUDE.md's UUID / timestamp / tombstone rule governs
/// **shareable** entities, and chat is not one: §3.1 gives it zero dependency on
/// networking and §2.2 puts sync out of scope. `isDeleted` is here anyway
/// because §6.1 lists it explicitly for this entity — see the note on
/// [ChatDao.deleteConversation] and technical-decisions #15.
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

  /// The rolling summary of turns folded out of the context window (§5.2.3),
  /// and the last message it accounts for.
  ///
  /// Model-derived but full of user content, so it lives here inside the
  /// encrypted database like everything else (§7.2) — never in a cache file.
  TextColumn get summary => text().nullable()();
  TextColumn get summaryUpToMessageId => text().nullable()();

  /// The prompt version and model this conversation was held under (§5.2.1,
  /// §5.3). Nullable: conversations created before the prompt layer existed
  /// have neither, and inventing a value would misreport which prompt produced
  /// their replies.
  TextColumn get systemPromptVersion => text().nullable()();
  TextColumn get modelId => text().nullable()();

  BoolColumn get isDeleted =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// One message in a conversation (technical-spec §6.1).
///
/// The index covers the one query the chat runs constantly: a conversation's
/// messages in reading order.
@DataClassName('MessageRow')
@TableIndex(name: 'messages_conversation_created', columns: {
  #conversationId,
  #createdAt,
})
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

  /// `user` | `assistant` | `system`, stored as text (§6.1).
  ///
  /// Deliberately **not** a boolean: the chat template (§5.2.2) maps roles to
  /// model-specific markers and a boolean cannot express the system role. Kept
  /// as a plain text column rather than a drift enum converter so the stored
  /// vocabulary is owned by `MessageRole.wireName` in the domain, where the
  /// parse failure can be meaningful. Validated on the way in and out by
  /// `DriftChatRepository`.
  TextColumn get role => text()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// User preferences: interface language, appearance, whether the first-run
/// screen has been seen.
///
/// A key/value table rather than a row of typed columns, because these are
/// settings rather than entities: adding one is an insert, not a migration, and
/// the set of them will keep growing while the shape never does. The keys
/// themselves are owned by `PreferenceKeys` in `features/settings/domain`, where
/// a value that cannot be parsed can be answered for.
///
/// **Why this is inside the encrypted database at all.** CLAUDE.md forbids
/// writing user data to disk outside it, and while a theme choice is not
/// sensitive, "sometimes we write outside the encrypted database" is not a rule
/// anyone can hold. One store, one answer (technical-decisions #23).
@DataClassName('PreferenceRow')
class Preferences extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// The application database: `lev.db`, opened through SQLCipher.
///
/// `schemaVersion 2` adds [Preferences]. The mutual-aid tables (`HelpRequest`,
/// `HelpCommitment` — §6.1) join it at this version when Phase 4 lands.
@DriftDatabase(
  tables: [Conversations, Messages, Preferences],
  daos: [ChatDao, PreferencesDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  /// Timestamps are stored as ISO-8601 **text**, not as unix seconds.
  ///
  /// Drift's default truncates to whole seconds, and that is not good enough
  /// here: in a streaming chat a user's message and the assistant's reply can
  /// land in the same second, and `ORDER BY createdAt` would then put them in an
  /// arbitrary order that changes between reads. Text keeps sub-second precision
  /// and sorts correctly as a string. Chosen now, at schemaVersion 1, because
  /// changing it later would mean rewriting every stored timestamp.
  ///
  /// `build.yaml` sets the same option for the *generator*, which is what
  /// `drift_dev schema dump` reads. The two must agree or the snapshot under
  /// `drift_schemas/` describes a database that does not exist.
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);

  /// The first migration that actually runs.
  ///
  /// Schema 1 shipped nowhere, but by the time [Preferences] was added the chat
  /// had been running against a real encrypted database on two platforms, so
  /// there are `lev.db` files at version 1 in the wild — on the development
  /// machines, at least. Creating one table is the whole of it; the dumps under
  /// `drift_schemas/` are what let `test/core/db/migration_test.dart` prove it
  /// rather than hope about it.
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(preferences);
        },
        // Set per connection, and re-set here because a migration opens its own.
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON;');
        },
      );
}

/// The chat queries. Returns drift rows; turning them into domain entities is
/// the job of `features/chat/data` (technical-spec §3.4 puts DAOs here, and
/// §3.2 keeps the domain free of drift).
@DriftAccessor(tables: [Conversations, Messages])
class ChatDao extends DatabaseAccessor<AppDatabase> with _$ChatDaoMixin {
  ChatDao(super.db);

  /// Most recently active first. Tombstoned conversations are excluded.
  Stream<List<ConversationRow>> watchConversations() {
    return (select(conversations)
          ..where((c) => c.isDeleted.equals(false))
          ..orderBy([(c) => OrderingTerm.desc(c.updatedAt)]))
        .watch();
  }

  Future<void> insertConversation(ConversationsCompanion conversation) {
    return into(conversations).insert(conversation);
  }

  /// One live conversation, or `null` if it is absent or tombstoned.
  Future<ConversationRow?> findConversation(String id) {
    return (select(conversations)
          ..where((c) => c.id.equals(id) & c.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  SimpleSelectStatement<$MessagesTable, MessageRow> _messagesOf(
    String conversationId,
  ) =>
      select(messages)
        ..where((m) => m.conversationId.equals(conversationId))
        ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]);

  /// Oldest first — reading order.
  Stream<List<MessageRow>> watchMessages(String conversationId) =>
      _messagesOf(conversationId).watch();

  /// Oldest first, once. See `ChatRepository.messagesOf` for why this exists
  /// alongside [watchMessages].
  Future<List<MessageRow>> messagesOf(String conversationId) =>
      _messagesOf(conversationId).get();

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

  /// Tombstones the conversation and **erases** its messages.
  ///
  /// The asymmetry is what §6.1 asks for read literally: `Conversation` has an
  /// `isDeleted` field and `Message` has none, so messages cannot be tombstoned
  /// even in principle. It is also the right behaviour here — this is a privacy
  /// product, and "deleted" that leaves every word of the conversation on disk
  /// would be a lie. The row survives only as a marker; the content does not.
  ///
  /// One transaction: a tombstoned conversation whose messages survived would
  /// keep that text alive with nothing left in the UI pointing at it.
  Future<void> deleteConversation(String id) {
    return transaction(() async {
      await (delete(messages)..where((m) => m.conversationId.equals(id))).go();
      await (update(conversations)..where((c) => c.id.equals(id))).write(
        const ConversationsCompanion(
          isDeleted: Value(true),
          // The summary is user content too (§7.2), and it outlived the
          // messages it was made from.
          summary: Value(null),
          summaryUpToMessageId: Value(null),
        ),
      );
    });
  }

  Future<void> updateTitle(String conversationId, String title) {
    return (update(conversations)..where((c) => c.id.equals(conversationId)))
        .write(ConversationsCompanion(title: Value(title)));
  }

  /// Records the rolling summary of a conversation (§5.2.3).
  Future<void> saveSummary(
    String conversationId,
    String summary,
    String upToMessageId,
  ) {
    return (update(conversations)
          ..where((c) => c.id.equals(conversationId)))
        .write(
      ConversationsCompanion(
        summary: Value(summary),
        summaryUpToMessageId: Value(upToMessageId),
      ),
    );
  }
}

/// Preference reads and writes.
///
/// [watch] rather than a one-shot read is what lets the appearance and the
/// language change the moment the user picks them, without the settings screen
/// having to reach up and rebuild the application root.
@DriftAccessor(tables: [Preferences])
class PreferencesDao extends DatabaseAccessor<AppDatabase>
    with _$PreferencesDaoMixin {
  PreferencesDao(super.db);

  Stream<Map<String, String>> watchAll() {
    return select(preferences).watch().map(
          (rows) => {for (final row in rows) row.key: row.value},
        );
  }

  Future<String?> read(String key) async {
    final row = await (select(preferences)..where((p) => p.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  /// Writing `null` removes the key, which is what "follow the device" is: the
  /// absence of a choice, not a third stored value. Storing a sentinel would
  /// mean every reader had to know the sentinel.
  Future<void> write(String key, String? value) async {
    if (value == null) {
      await (delete(preferences)..where((p) => p.key.equals(key))).go();
      return;
    }
    await into(preferences).insertOnConflictUpdate(
      PreferencesCompanion.insert(key: key, value: value),
    );
  }

  /// Erases every preference. Part of "delete all data" — the theme choice is
  /// not sensitive, but "start over" that leaves settings behind is not a start
  /// over.
  Future<void> clear() => delete(preferences).go();
}
