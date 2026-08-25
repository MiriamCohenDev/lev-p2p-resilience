import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/chat/presentation/chat_screen.dart';
import '../../features/chat/presentation/conversation_list_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/mutual_aid/presentation/tasks_screen.dart';
import 'app_routes.dart';

/// The application router.
///
/// Exposed through Riverpod rather than as a global so tests (and future
/// redirect logic, e.g. a PIN lock screen) can override it.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        name: AppRoutes.homeName,
        builder: (context, state) => const HomeScreen(),
        // Nested so each screen is pushed rather than replacing the stack,
        // giving every one a working back affordance.
        routes: [
          GoRoute(
            path: AppRoutes.conversationsSegment,
            name: AppRoutes.conversationsName,
            builder: (context, state) => const ConversationListScreen(),
            routes: [
              GoRoute(
                path: AppRoutes.chatSegment,
                name: AppRoutes.chatName,
                builder: (context, state) => ChatScreen(
                  conversationId:
                      state.pathParameters[AppRoutes.conversationIdParam]!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.tasksSegment,
            name: AppRoutes.tasksName,
            builder: (context, state) => const TasksScreen(),
          ),
        ],
      ),
    ],
  );
});
