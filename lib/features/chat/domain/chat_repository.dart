import 'conversation.dart';
import 'message.dart';

/// The chat feature's only route to storage (technical-spec §5.1).
///
/// Everything above this interface — `ChatNotifier`, the screen — is written
/// against it, so the Drift implementation stays swappable and testable
/// (CLAUDE.md: all persistence goes through repositories; never SQL from UI or
/// domain).
///
/// **Wider than §5.1's illustrative sketch, deliberately.** That sketch lists
/// [watchMessages] (as `watchConversation`) and [append] only.
/// [createConversation] is not optional — a message cannot be appended to a
/// conversation that does not exist, and the foreign key now enforces it.
/// [watchConversations] is what gives `Conversation.title` a purpose.
///
/// There is no delete or rename: product-spec §5 lists no conversation
/// management action, and §6 describes a chat screen with an input field and a
/// message window, nothing more.
abstract class ChatRepository {
  /// All conversations, most recently active first. Re-emits on every change.
  Stream<List<Conversation>> watchConversations();

  /// Creates and stores a conversation, returning it as stored.
  Future<Conversation> createConversation({String? title});

  /// The messages of one conversation, oldest first. Re-emits on every append.
  Stream<List<Message>> watchMessages(String conversationId);

  /// Stores [message] and marks its conversation as active.
  ///
  /// Throws if the conversation does not exist.
  Future<void> append(Message message);
}
