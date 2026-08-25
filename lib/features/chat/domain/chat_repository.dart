import 'conversation.dart';
import 'message.dart';

/// The chat feature's only route to storage (technical-spec §5.1).
///
/// Everything above this interface — `ChatNotifier`, the screen — is written
/// against it, so the Drift implementation stays swappable and testable
/// (CLAUDE.md: all persistence goes through repositories; never SQL from UI or
/// domain).
///
/// **One deliberate naming deviation from §5.1's sketch.** The sketch calls the
/// message stream `watchConversation`; it is [watchMessages] here, because a
/// method named for a conversation that returns a list of messages reads
/// backwards at every call site. Every other member matches the sketch. See
/// technical-decisions #15.
abstract class ChatRepository {
  /// Live conversations, most recently active first. Re-emits on every change.
  ///
  /// Tombstoned conversations are excluded — a deleted conversation is gone as
  /// far as every caller above this interface is concerned.
  Stream<List<Conversation>> watchConversations();

  /// Creates and stores a conversation, returning it as stored.
  ///
  /// [systemPromptVersion] and [modelId] are recorded on the row so a later
  /// change in either is traceable to the conversations held before it (§5.2.1).
  Future<Conversation> createConversation({
    String? title,
    String? systemPromptVersion,
    String? modelId,
  });

  /// One conversation by id, or `null` if it does not exist or is tombstoned.
  ///
  /// Needed by the prompt layer: [Conversation.summary] is an input to
  /// `PromptBuilder.buildSeed`, and the seed is built when a conversation is
  /// opened rather than when the list is watched.
  Future<Conversation?> findConversation(String conversationId);

  /// Tombstones a conversation and erases its messages.
  Future<void> deleteConversation(String conversationId);

  /// Sets a conversation's title.
  ///
  /// **Derived, not user-edited.** Product-spec §5 lists no rename action, and
  /// none is offered. A conversation is created before its first message exists,
  /// so it has nothing to be called; the chat sets the title from the opening
  /// message so the conversation list is something a person can navigate rather
  /// than a column of identical placeholders.
  Future<void> updateTitle(String conversationId, String title);

  /// The messages of one conversation, oldest first. Re-emits on every append.
  Stream<List<Message>> watchMessages(String conversationId);

  /// Reads the messages of one conversation once, oldest first.
  ///
  /// The seed is assembled from a snapshot, not from a stream: `buildSeed`
  /// needs the history as it stands at open time, and awaiting `.first` on a
  /// watch stream to get it would leave a subscription behind.
  Future<List<Message>> messagesOf(String conversationId);

  /// Stores [message] and marks its conversation as active.
  ///
  /// Throws if the conversation does not exist.
  Future<void> append(Message message);

  /// Persists the rolling summary of [conversationId] (§5.2.3).
  ///
  /// [upToMessageId] records how far the summary accounts for; everything after
  /// it is still carried verbatim in the prompt.
  Future<void> saveSummary(
    String conversationId,
    String summary,
    String upToMessageId,
  );
}
