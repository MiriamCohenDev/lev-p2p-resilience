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
