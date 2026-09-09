import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/chat/presentation/chat_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/mutual_aid/presentation/tasks_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import 'app_routes.dart';

/// The application router.
///
/// Exposed through Riverpod rather than as a global so tests can override it.
///
/// **There is no onboarding redirect here.** Whether the welcome screen has been
/// seen is a preference, and reading it means opening the encrypted database —
/// an asynchronous answer that a `redirect` would have to guess at while it
/// loads, and a `refreshListenable` to correct afterwards. It is a gate around
/// the router instead: see `LevApp`. That also gives the database's own failure
/// modes somewhere to be shown, which nothing did before.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        name: AppRoutes.homeName,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.chat,
        name: AppRoutes.chatName,
        builder: (context, state) => const ChatScreen(),
        routes: [
          GoRoute(
            path: ':${AppRoutes.conversationIdParam}',
            name: AppRoutes.conversationName,
            builder: (context, state) => ChatScreen(
              conversationId:
                  state.pathParameters[AppRoutes.conversationIdParam],
              // The message the draft was carrying when it created this
              // conversation, if that is how we arrived (technical-decisions
              // #34). Null on every other route into a conversation.
              initialMessage: state.extra as String?,
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.aid,
        name: AppRoutes.aidName,
        builder: (context, state) => const TasksScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: AppRoutes.settingsName,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
