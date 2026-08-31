import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lev/core/l10n/app_localizations.dart';
import 'package:lev/features/home/presentation/home_screen.dart';

import '../support/chat_harness.dart';

/// English and Hebrew, including RTL (technical-decisions #11).
///
/// Home is pumped through [ChatHarness] rather than under a bare `MaterialApp`:
/// it reads the conversation list, and the LEV widgets read their colours from
/// the `LevColors` theme extension, so both have to be present for the screen to
/// build at all.
void main() {
  test('English and Hebrew are both supported locales', () {
    expect(AppLocalizations.supportedLocales, contains(const Locale('en')));
    expect(AppLocalizations.supportedLocales, contains(const Locale('he')));
  });

  chatWidgetTest('Hebrew lays out right-to-left', (tester, harness) async {
    await harness.pump(
      tester,
      const HomeScreen(),
      locale: const Locale('he'),
    );

    expect(
      Directionality.of(tester.element(find.byType(HomeScreen))),
      TextDirection.rtl,
    );

    final he = await AppLocalizations.delegate.load(const Locale('he'));
    expect(find.text(he.homeStartChat), findsOneWidget);
    expect(find.text(he.navAid), findsOneWidget);
  });

  chatWidgetTest('English lays out left-to-right', (tester, harness) async {
    await harness.pump(
      tester,
      const HomeScreen(),
      locale: const Locale('en'),
    );

    expect(
      Directionality.of(tester.element(find.byType(HomeScreen))),
      TextDirection.ltr,
    );

    final en = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(en.homeStartChat), findsOneWidget);
  });
}
