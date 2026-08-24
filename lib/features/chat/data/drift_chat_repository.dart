import '../../../core/db/app_database.dart';
import '../domain/chat_repository.dart';
import '../domain/conversation.dart';
import '../domain/message.dart';

/// [ChatRepository] over Drift.
///
/// This class is the whole of the translation between the two worlds: drift row
/// classes (`ConversationRow`, `MessageRow`) live below it, domain entities
/// above it, and nothing outside this file sees both.
class DriftChatRepository implements ChatRepository {
  DriftChatRepository(this._dao);

  final ChatDao _dao;

  @override
  Stream<List<Conversation>> watchConversations() =>
      _dao.watchConversations().map((rows) => rows.map(_toDomain).toList());

  @override
  Future<Conversation> createConversation({String? title}) async {
    final conversation = Conversation.create(title: title ?? '');
    await _dao.insertConversation(
      ConversationsCompanion.insert(
        id: conversation.id,
        title: conversation.title,
        createdAt: conversation.createdAt,
        updatedAt: conversation.updatedAt,
      ),
    );
    return conversation;
  }

  @override
  Stream<List<Message>> watchMessages(String conversationId) => _dao
      .watchMessages(conversationId)
      .map((rows) => rows.map(_toDomainMessage).toList());

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
        fromUser: message.fromUser,
        createdAt: message.createdAt,
      ),
      message.createdAt,
    );
  }

  Conversation _toDomain(ConversationRow row) => Conversation(
        id: row.id,
        title: row.title,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );

  Message _toDomainMessage(MessageRow row) => Message(
        id: row.id,
        conversationId: row.conversationId,
        // `body` on the row, `text` in the domain and in the SQL column — see
        // the note on Messages.body.
        text: row.body,
        fromUser: row.fromUser,
        createdAt: row.createdAt,
      );
}
