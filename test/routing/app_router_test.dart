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

  /// Entering the chat creates nothing; the first message does
  /// (technical-decisions #34, superseding #32).
  group('the chat destination opens a composer, not a conversation', () {
    Future<void> openChat(WidgetTester tester) async {
      await tester.tap(find.text(l10n.navChat));
      await tester.pumpAndSettle();
    }

    Future<void> send(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
    }

    chatWidgetTest('entering the chat lands on a composer with nothing behind it',
        (tester, harness) async {
      await harness.pumpApp(tester);
      await openChat(tester);

      // Somewhere to type, rather than a button asking to confirm the thing
      // that opening the chat already said — and no row for having arrived.
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(l10n.homeStartChat), findsNothing);
      expect(await harness.conversations(), isEmpty);
    }, replies: ['ok']);

    chatWidgetTest('the first message is what creates the conversation',
        (tester, harness) async {
      await harness.pumpApp(tester);
      await openChat(tester);
      await send(tester, 'the first thing');

      final conversations = await harness.conversations();
      expect(conversations, hasLength(1));
      // Named after what was said, which is what makes the row worth having.
      expect(conversations.single.title, 'the first thing');

      // And the message itself was not swallowed on the way across the
      // navigation: it is in the conversation, answered.
      final stored = await harness.repository.messagesOf(conversations.single.id);
      expect(stored.map((m) => m.text), ['the first thing', 'ok']);
    }, replies: ['ok']);

    chatWidgetTest('the message is sent once, not twice', (tester, harness) async {
      await harness.pumpApp(tester);
      await openChat(tester);
      await send(tester, 'only once');

      // The message crosses the navigation as route `extra`, which outlives the
      // build that consumes it — so a rebuild must not send it again.
      await tester.pumpAndSettle();

      final id = (await harness.conversations()).single.id;
      final said = await harness.repository.messagesOf(id);
      expect(said.where((m) => m.text == 'only once'), hasLength(1));
    }, replies: ['ok']);

    chatWidgetTest('leaving and coming back still creates nothing',
        (tester, harness) async {
      await harness.pumpApp(tester);
      await openChat(tester);

      await tester.tap(find.text(l10n.navHome));
      await tester.pumpAndSettle();
      await openChat(tester);

      // The chat is a permanent destination, so it is entered and left
      // repeatedly. Nothing about crossing it is a conversation.
      expect(await harness.conversations(), isEmpty);
    }, replies: ['ok']);

    chatWidgetTest('coming back after speaking starts a fresh one',
        (tester, harness) async {
      await harness.pumpApp(tester);
      await openChat(tester);
      await send(tester, 'something said');

      await tester.tap(find.text(l10n.navHome));
      await tester.pumpAndSettle();
      await openChat(tester);

      // Still one: entering the chat again is a blank composer, not a second
      // row. Resuming the first is what the history, and Home's resume card,
      // are for.
      expect(await harness.conversations(), hasLength(1));

      await send(tester, 'and another thing');
      expect(await harness.conversations(), hasLength(2));
    }, replies: ['ok']);
  });

  chatWidgetTest("Home's primary action opens the chat and creates nothing",
      (tester, harness) async {
    await harness.pumpApp(tester);

    await tester.tap(find.text(l10n.homeStartChat));
    await tester.pumpAndSettle();

    expect(find.byType(ChatScreen), findsOneWidget);
    expect(await harness.conversations(), isEmpty);
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
