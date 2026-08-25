import '../domain/message.dart';

/// What the chat screen renders (technical-spec §5.1).
///
/// [messages] is the persisted conversation, mirrored from the repository's
/// stream; [streamingText] is the reply currently arriving, which is **not** in
/// the database yet. Keeping them apart is deliberate — see `ChatNotifier` for
/// why the in-flight reply is written once at the end rather than per token.
class ChatState {
  const ChatState({
    this.messages = const [],
    this.isTyping = false,
    this.isPrefilling = false,
    this.streamingText = '',
    this.failure,
    this.safetyNotice,
  });

  final List<Message> messages;

  /// A reply is being generated.
  final bool isTyping;

  /// The session is prefilling the seed (§5.1).
  ///
  /// Distinct from `isTyping`: prefill is the cost of *opening* a conversation,
  /// and §8 requires the UI to surface it explicitly — "a blank or frozen screen
  /// is a defect".
  final bool isPrefilling;

  /// The reply so far, token by token. Empty when nothing is generating.
  final String streamingText;

  /// The last generation failure, or `null`. Cleared when a new turn starts.
  ///
  /// Held rather than thrown: tokens already delivered are real and stay on
  /// screen, so this reports that the *rest* is not coming.
  final Object? failure;

  /// A fixed support message from the safety layer, to be shown **alongside**
  /// the reply (§5.2.4). Populated in Phase 2.3.
  final String? safetyNotice;

  /// True while the user should not be able to send another turn.
  bool get isBusy => isTyping || isPrefilling;

  ChatState copyWith({
    List<Message>? messages,
    bool? isTyping,
    bool? isPrefilling,
    String? streamingText,
    Object? failure,
    String? safetyNotice,
    bool clearFailure = false,
    bool clearSafetyNotice = false,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        isTyping: isTyping ?? this.isTyping,
        isPrefilling: isPrefilling ?? this.isPrefilling,
        streamingText: streamingText ?? this.streamingText,
        failure: clearFailure ? null : (failure ?? this.failure),
        safetyNotice:
            clearSafetyNotice ? null : (safetyNotice ?? this.safetyNotice),
      );
}
