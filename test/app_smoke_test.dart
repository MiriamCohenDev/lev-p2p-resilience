import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lev/core/l10n/app_localizations.dart';
import 'package:lev/core/widgets/lev_logo.dart';
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

    // The one screen that introduces the product by name: the stacked lockup,
    // wordmark and all.
    final logo = tester.widget<LevLogo>(find.byType(LevLogo));
    expect(logo.variant, LevLogoVariant.vertical);
    expect(find.text('LEV'), findsOneWidget);
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

  chatWidgetTest('Home greets and offers one action, under the mark alone',
      (tester, harness) async {
    await harness.pumpApp(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text(l10n.homeStartChat), findsOneWidget);

    // The bar carries the symbol and **not** the word. `appTitle` still exists,
    // but only as the window and task-switcher name — it is no longer a source
    // of text on any screen.
    expect(
      tester.widget<LevLogo>(find.byType(LevLogo)).variant,
      LevLogoVariant.mark,
    );
    expect(find.text('LEV'), findsNothing);
  });

  chatWidgetTest('the model loads at startup, before the chat is ever opened',
      (tester, harness) async {
    await harness.pumpApp(tester);

    // Nothing here navigates: the app is sitting on Home and `_ChatBody` — which
    // used to be the first and only watcher of `llmServiceProvider` — has never
    // been built. The weights are loaded anyway, because `_ModelWarmUp` started
    // them at the first frame (#35).
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(harness.engine.loadedModel, isNotNull);
  });

  chatWidgetTest('the warm-up survives the welcome screen', (tester, harness) async {
    // The warm-up sits above the first-run gate, so a launch that has not been
    // through onboarding loads the model too — which is the launch where the
    // weights have to be extracted from the asset bundle, and the one where
    // nothing else is competing for them.
    await harness.pumpApp(tester, onboardingSeen: false);

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(harness.engine.loadedModel, isNotNull);
  });
}
