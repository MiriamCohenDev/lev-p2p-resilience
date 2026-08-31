import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lev/core/l10n/app_localizations.dart';
import 'package:lev/features/home/presentation/home_screen.dart';
import 'package:lev/features/onboarding/presentation/welcome_screen.dart';

import 'support/chat_harness.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  chatWidgetTest('a first run opens the welcome screen', (tester, harness) async {
    await harness.pumpApp(tester, onboardingSeen: false);

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text(l10n.welcomeTagline), findsOneWidget);
    // The warning is in the body of the card, at the same size as the rest, and
    // before the decision — not in small print.
    expect(find.text(l10n.welcomeLockWarning), findsOneWidget);
  });

  chatWidgetTest('accepting the welcome screen opens Home, and it stays open',
      (tester, harness) async {
    await harness.pumpApp(tester, onboardingSeen: false);

    // The card stack is taller than the 800×600 test surface, so the button has
    // to be scrolled to before it can be tapped — the same thing that happens on
    // a small phone.
    await tester.ensureVisible(find.text(l10n.welcomeStart));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.welcomeStart));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);

    // It is a stored preference, not a flag in memory: rebuilding the whole
    // application must not show the welcome screen again.
    await harness.pumpApp(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(WelcomeScreen), findsNothing);
  });

  chatWidgetTest('Home greets, offers one action, and names the app',
      (tester, harness) async {
    await harness.pumpApp(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text(l10n.appTitle), findsOneWidget);
    expect(find.text(l10n.homeStartChat), findsOneWidget);
  });
}
