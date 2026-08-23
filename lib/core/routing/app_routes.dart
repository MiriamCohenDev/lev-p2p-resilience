/// Route paths and names, kept in one place so screens never hardcode strings.
///
/// Chat and Tasks are nested under Home, so each has both a path *segment*
/// (what `GoRoute` is declared with) and a full *location* (what callers
/// navigate to).
abstract final class AppRoutes {
  static const String home = '/';

  static const String chatSegment = 'chat';
  static const String tasksSegment = 'tasks';

  static const String chat = '/$chatSegment';
  static const String tasks = '/$tasksSegment';

  static const String homeName = 'home';
  static const String chatName = 'chat';
  static const String tasksName = 'tasks';
}
