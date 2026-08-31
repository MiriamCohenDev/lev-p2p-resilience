/// Route paths and names, kept in one place so screens never hardcode strings.
///
/// **Flat, not nested — this supersedes the nesting of technical-decisions #9.**
/// The design puts three permanent destinations in a bar (Home · Chat · Help)
/// with the conversation list in a drawer, rather than a `Home → Conversations →
/// Chat` stack. Tabs are siblings, so a stack between them would be wrong: going
/// Home from a conversation is not "back".
///
/// What was lost with the nesting is per-tab navigation state, and here that is
/// a feature rather than a cost — `chatNotifierProvider` is `autoDispose`
/// precisely because §5.1 wants a conversation's session, and its KV cache,
/// released when the conversation is left.
abstract final class AppRoutes {
  static const String home = '/';

  /// The chat with no conversation chosen. Shows the empty state and offers the
  /// history, rather than redirecting: a redirect would need the conversation
  /// list before the router could answer, and the empty state is a real screen
  /// the design specifies anyway.
  static const String chat = '/chat';

  /// The conversation id, as it appears in the path and in `state.pathParameters`.
  static const String conversationIdParam = 'conversationId';

  static const String aid = '/aid';

  /// Pushed rather than switched to: it is not a destination, and it has a back
  /// affordance in the design.
  static const String settings = '/settings';

  /// The location of one conversation.
  static String conversation(String conversationId) => '$chat/$conversationId';

  static const String homeName = 'home';
  static const String chatName = 'chat';
  static const String conversationName = 'conversation';
  static const String aidName = 'aid';
  static const String settingsName = 'settings';
}
