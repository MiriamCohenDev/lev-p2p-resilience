import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lev/core/l10n/app_localizations.dart';
import 'package:lev/features/chat/presentation/chat_screen.dart';
import 'package:lev/features/home/presentation/home_screen.dart';
import 'package:lev/features/mutual_aid/presentation/tasks_screen.dart';
import 'package:lev/features/settings/presentation/settings_screen.dart';

import '../support/chat_harness.dart';

/// Navigation across the app.
///
/// The three destinations are **siblings in a bar**, not a stack: switching to
/// Home from a conversation is not "back" (technical-decisions #22, superseding
/// the nesting in #9). Settings is the one screen that is pushed, because it has
/// a back affordance in the design.
///
/// Every case runs under [chatWidgetTest] because the shell reaches storage as
/// soon as it is built — the first-run gate reads a preference — and a host test
/// has no secure store to unwrap a DEK from.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  chatWidgetTest('the bar switches between the three destinations',
      (tester, harness) async {
    await harness.pumpApp(tester);
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.text(l10n.navAid));
    await tester.pumpAndSettle();
    expect(find.byType(TasksScreen), findsOneWidget);

    await tester.tap(find.text(l10n.navChat));
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsOneWidget);

    await tester.tap(find.text(l10n.navHome));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  }, replies: ['ok']);

  group('the chat destination opens a conversation, not a button', () {
    /// Enters the chat from the bar and lets the conversation open.
    Future<void> openChat(WidgetTester tester) async {
      await tester.tap(find.text(l10n.navChat));
      await tester.pumpAndSettle();
    }

    chatWidgetTest('entering the chat lands in a conversation',
        (tester, harness) async {
      await harness.pumpApp(tester);
      await openChat(tester);

      // A composer to type into, rather than a button asking to confirm the
      // thing that opening the chat already said.
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(l10n.homeStartChat), findsNothing);
      expect(await harness.conversations(), hasLength(1));
    }, replies: ['ok']);

    chatWidgetTest('leaving and coming back reuses the blank conversation',
        (tester, harness) async {
      await harness.pumpApp(tester);
      await openChat(tester);

      await tester.tap(find.text(l10n.navHome));
      await tester.pumpAndSettle();
      await openChat(tester);

      // The chat is a permanent destination, so it is entered and left
      // repeatedly. One untitled row per visit would fill the history.
      expect(await harness.conversations(), hasLength(1));
    }, replies: ['ok']);

    chatWidgetTest('coming back to a conversation spoken in starts a new one',
        (tester, harness) async {
      await harness.pumpApp(tester);
      await openChat(tester);

      await tester.enterText(find.byType(TextField), 'something said');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.navHome));
      await tester.pumpAndSettle();
      await openChat(tester);

      // Reuse is for a conversation nobody said anything in — resuming one is
      // what the history, and Home's resume card, are for.
      expect(await harness.conversations(), hasLength(2));
    }, replies: ['ok']);
  });

  chatWidgetTest("Home's primary action creates a conversation and opens it",
      (tester, harness) async {
    await harness.pumpApp(tester);

    await tester.tap(find.text(l10n.homeStartChat));
    await tester.pumpAndSettle();

    expect(find.byType(ChatScreen), findsOneWidget);
    expect(await harness.conversations(), hasLength(1));
  }, replies: ['ok']);

  chatWidgetTest('settings is pushed, and comes back to where it was opened',
      (tester, harness) async {
    await harness.pumpApp(tester);

    await tester.tap(find.byTooltip(l10n.settingsTitle));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  }, replies: ['ok']);
}
