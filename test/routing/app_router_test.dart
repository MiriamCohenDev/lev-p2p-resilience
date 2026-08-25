import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lev/core/l10n/app_localizations.dart';
import 'package:lev/features/chat/presentation/chat_screen.dart';
import 'package:lev/features/chat/presentation/conversation_list_screen.dart';
import 'package:lev/features/home/presentation/home_screen.dart';
import 'package:lev/features/mutual_aid/presentation/tasks_screen.dart';

import '../support/chat_harness.dart';

/// Navigation across the app.
///
/// Every case runs under [chatWidgetTest] because the conversation list reaches
/// storage as soon as it is built, and a host test has no secure store to unwrap
/// a DEK from — the harness substitutes an in-memory database for the same
/// reason `test/core/crypto/` substitutes the key store.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  chatWidgetTest('Home navigates to the conversation list and back',
      (tester, harness) async {
    await harness.pumpApp(tester);

    await tester.tap(find.text(l10n.homeOpenChat));
    await tester.pumpAndSettle();
    expect(find.byType(ConversationListScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  }, replies: ['ok']);

  chatWidgetTest(
      'a new conversation opens the chat, and back returns to the list',
      (tester, harness) async {
    await harness.pumpApp(tester);

    await tester.tap(find.text(l10n.homeOpenChat));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.conversationsNew));
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsOneWidget);

    // Nested routing is what gives this a back stack at all: Chat under
    // Conversations under Home (see AppRoutes).
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ConversationListScreen), findsOneWidget);
  }, replies: ['ok']);

  chatWidgetTest('Home navigates to Tasks and back', (tester, harness) async {
    await harness.pumpApp(tester);

    await tester.tap(find.text(l10n.homeOpenTasks));
    await tester.pumpAndSettle();
    expect(find.byType(TasksScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  }, replies: ['ok']);
}
