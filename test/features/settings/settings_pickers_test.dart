import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lev/core/l10n/app_localizations.dart';
import 'package:lev/core/widgets/lev_widgets.dart';
import 'package:lev/features/settings/domain/settings.dart';
import 'package:lev/features/settings/presentation/settings_screen.dart';

import '../../support/chat_harness.dart';

/// The language and appearance pickers.
///
/// **These existed untested, and it cost a regression.** The pickers put
/// `LevListRow` inside an `AlertDialog`, which is the one place in the product
/// where a row is laid out under `IntrinsicWidth` — and `IntrinsicWidth` asks
/// its children for intrinsic dimensions. A `LayoutBuilder` added to the row to
/// bound its `value` could not answer that question, so every row in both
/// dialogs threw on layout: the dialog opened, drew nothing usable, and the
/// screen read as frozen. Nothing failed, because nothing was looking.
///
/// So these tests are not about the pickers being pretty. They are about a
/// shared component surviving the second context it is used in.
void main() {
  chatWidgetTest('the language picker opens and lists every choice',
      (tester, harness) async {
    await harness.pump(tester, const SettingsScreen());
    final en = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text(en.settingsLanguage));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    // The rows themselves rendered. Under the broken layout the dialog was
    // still there and these were not.
    expect(find.text(en.settingsFollowDevice), findsWidgets);
    expect(find.text(en.languageHebrew), findsOneWidget);
    expect(find.text(en.languageEnglish), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  chatWidgetTest('choosing a language stores it', (tester, harness) async {
    await harness.pump(tester, const SettingsScreen());
    final en = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text(en.settingsLanguage));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.languageHebrew));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(
      await harness.database.preferencesDao.read('ui.languageCode'),
      'he',
    );
  });

  chatWidgetTest('the appearance picker opens and stores a choice',
      (tester, harness) async {
    await harness.pump(tester, const SettingsScreen());
    final en = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text(en.settingsAppearance));
    await tester.pumpAndSettle();

    expect(find.text(en.settingsAppearanceDark), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text(en.settingsAppearanceDark));
    await tester.pumpAndSettle();

    expect(
      await harness.database.preferencesDao.read('ui.appearance'),
      LevAppearance.dark.name,
    );
  });

  chatWidgetTest('a row survives being laid out for its intrinsic width',
      (tester, harness) async {
    // The failure above, reduced to the thing that actually caused it. A row
    // that cannot report an intrinsic width breaks anywhere Flutter asks for
    // one — `AlertDialog` today, an `IntrinsicHeight` or a `DataTable`
    // tomorrow — so the guard belongs on the component, not on the screen.
    await harness.pump(
      tester,
      // `Material` because `LevListRow` is an `InkWell`; in the app it is the
      // `Scaffold`'s, and in a dialog it is the `AlertDialog`'s.
      const Material(
        child: Center(
          child: IntrinsicWidth(
            child: LevListRow(
              title: 'Interface language',
              value: 'Follow the device',
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Follow the device'), findsOneWidget);
  });
}
