/// Route paths and names, kept in one place so screens never hardcode strings.
///
/// Conversations and Tasks are nested under Home, and Chat is nested under
/// Conversations, so each screen has a real back stack: a conversation returns
/// to the list, and the list returns Home.
abstract final class AppRoutes {
  static const String home = '/';

  static const String conversationsSegment = 'conversations';
  static const String tasksSegment = 'tasks';

  /// The conversation id, as it appears in the path and in `state.pathParameters`.
  static const String conversationIdParam = 'conversationId';
  static const String chatSegment = ':$conversationIdParam';

  static const String conversations = '/$conversationsSegment';
  static const String tasks = '/$tasksSegment';

  /// The location of one conversation.
  static String chat(String conversationId) =>
      '$conversations/$conversationId';

  static const String homeName = 'home';
  static const String conversationsName = 'conversations';
  static const String chatName = 'chat';
  static const String tasksName = 'tasks';
}
