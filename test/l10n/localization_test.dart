import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lev/core/l10n/app_localizations.dart';
import 'package:lev/features/home/presentation/home_screen.dart';

/// Pumps a screen under a fixed locale, bypassing the router so the test
/// exercises localization alone.
Future<void> pumpLocalized(WidgetTester tester, Locale locale) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HomeScreen(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('English and Hebrew are both supported locales', () {
    expect(AppLocalizations.supportedLocales, contains(const Locale('en')));
    expect(AppLocalizations.supportedLocales, contains(const Locale('he')));
  });

  testWidgets('Hebrew locale lays out right-to-left', (tester) async {
    await pumpLocalized(tester, const Locale('he'));

    expect(
      Directionality.of(tester.element(find.byType(HomeScreen))),
      TextDirection.rtl,
    );
  });

  testWidgets('English locale lays out left-to-right', (tester) async {
    await pumpLocalized(tester, const Locale('en'));

    expect(
      Directionality.of(tester.element(find.byType(HomeScreen))),
      TextDirection.ltr,
    );
  });

  testWidgets('Hebrew strings are used under the Hebrew locale',
      (tester) async {
    final he = await AppLocalizations.delegate.load(const Locale('he'));
    await pumpLocalized(tester, const Locale('he'));

    expect(find.text(he.homeOpenChat), findsOneWidget);
    expect(find.text(he.homeOpenTasks), findsOneWidget);
  });
}
