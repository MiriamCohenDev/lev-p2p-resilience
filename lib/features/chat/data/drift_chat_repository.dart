import 'package:drift/drift.dart' show Value;

import '../../../core/db/app_database.dart';
import '../domain/chat_repository.dart';
import '../domain/conversation.dart';
import '../domain/message.dart';
import '../domain/message_role.dart';

/// [ChatRepository] over Drift.
///
/// This class is the whole of the translation between the two worlds: drift row
/// classes (`ConversationRow`, `MessageRow`) live below it, domain entities
/// above it, and nothing outside this file sees both. That includes the
/// `role` column's vocabulary, which is owned by [MessageRole] and crosses the
/// boundary only here.
class DriftChatRepository implements ChatRepository {
  DriftChatRepository(this._dao);

  final ChatDao _dao;

  @override
  Stream<List<Conversation>> watchConversations() =>
      _dao.watchConversations().map((rows) => rows.map(_toDomain).toList());

  @override
  Future<Conversation?> latestConversation() async {
    final row = await _dao.latestConversation();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<Conversation> createConversation({
    String? title,
    String? systemPromptVersion,
    String? modelId,
  }) async {
    final conversation = Conversation.create(
      title: title ?? '',
      systemPromptVersion: systemPromptVersion,
      modelId: modelId,
    );
    await _dao.insertConversation(
      ConversationsCompanion.insert(
        id: conversation.id,
        title: conversation.title,
        createdAt: conversation.createdAt,
        updatedAt: conversation.updatedAt,
        systemPromptVersion: Value(conversation.systemPromptVersion),
        modelId: Value(conversation.modelId),
      ),
    );
    return conversation;
  }

  @override
  Future<Conversation?> findConversation(String conversationId) async {
    final row = await _dao.findConversation(conversationId);
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> deleteConversation(String conversationId) =>
      _dao.deleteConversation(conversationId);

  @override
  Future<void> updateTitle(String conversationId, String title) =>
      _dao.updateTitle(conversationId, title);

  @override
  Stream<List<Message>> watchMessages(String conversationId) => _dao
      .watchMessages(conversationId)
      .map((rows) => rows.map(_toDomainMessage).toList());

  @override
  Future<List<Message>> messagesOf(String conversationId) async {
    final rows = await _dao.messagesOf(conversationId);
    return rows.map(_toDomainMessage).toList();
  }

  @override
  Future<void> append(Message message) {
    // The message's own timestamp becomes the conversation's `updatedAt`, so the
    // list order reflects when the conversation was last spoken in rather than
    // when the write happened to land.
    return _dao.appendMessage(
      MessagesCompanion.insert(
        id: message.id,
        conversationId: message.conversationId,
        body: message.text,
        role: message.role.wireName,
        createdAt: message.createdAt,
      ),
      message.createdAt,
    );
  }

  @override
  Future<void> saveSummary(
    String conversationId,
    String summary,
    String upToMessageId,
  ) =>
      _dao.saveSummary(conversationId, summary, upToMessageId);

  Conversation _toDomain(ConversationRow row) => Conversation(
        id: row.id,
        title: row.title,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        summary: row.summary,
        summaryUpToMessageId: row.summaryUpToMessageId,
        systemPromptVersion: row.systemPromptVersion,
        modelId: row.modelId,
        isDeleted: row.isDeleted,
      );

  Message _toDomainMessage(MessageRow row) => Message(
        id: row.id,
        conversationId: row.conversationId,
        // `body` on the row, `text` in the domain and in the SQL column — see
        // the note on Messages.body.
        text: row.body,
        role: MessageRole.fromWireName(row.role),
        createdAt: row.createdAt,
      );
}
