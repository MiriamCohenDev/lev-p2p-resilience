import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lev/core/app_info.dart';
import 'package:lev/core/l10n/app_localizations.dart';
import 'package:lev/core/support/support_resources.dart';
import 'package:lev/core/widgets/lev_widgets.dart';
import 'package:lev/features/settings/presentation/settings_screen.dart';

import '../../support/chat_harness.dart';

/// The About section, pumped inside the real settings screen.
///
/// Inside the screen rather than on its own, because half of what is being
/// asserted is that it *is* the last section of Settings — not a screen with a
/// route, not a card on Home. A test that pumped the section alone would still
/// pass if somebody moved it.
void main() {
  /// Brings [finder] on screen before a gesture.
  ///
  /// Only gestures need this. Settings scrolls in a `SingleChildScrollView`,
  /// which builds its whole child, so `find.text` matches the section at 600×800
  /// without any scrolling — but a tap or a long press still has to land inside
  /// the viewport.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  chatWidgetTest('it is the last section of Settings, not a screen of its own',
      (tester, harness) async {
    await harness.pump(tester, const SettingsScreen());
    final en = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(en.settingsGroupAbout), findsOneWidget);
    // The brand signature, quietly — the mark and the name, not the stacked
    // lockup that belongs to the splash and the first run.
    expect(find.byType(LevBrandLine), findsOneWidget);
  });

  chatWidgetTest('the four statements appear, word for word',
      (tester, harness) async {
    await harness.pump(tester, const SettingsScreen());
    final en = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(en.aboutHowItWorks), findsOneWidget);
    // These four are the whole of the text in this section. They are asserted
    // individually so that dropping one — the deletion sentence is the one that
    // would go, being the least comfortable — fails rather than passes quietly.
    for (final line in [
      en.aboutFactStorage,
      en.aboutFactNoAccount,
      en.aboutFactOnDevice,
      en.aboutFactDeletion,
    ]) {
      expect(find.text(line), findsOneWidget, reason: line);
    }
  });

  chatWidgetTest('the version row shows the build number and copies itself',
      (tester, harness) async {
    // The clipboard is a platform channel; without this the write throws.
    final written = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          written.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await harness.pump(tester, const SettingsScreen());
    final en = await AppLocalizations.delegate.load(const Locale('en'));

    final value = en.aboutVersionValue(AppInfo.version, AppInfo.buildNumber);
    expect(find.text(value), findsOneWidget);
    // Not just the version: with no store and no crash reporting, the build
    // number is the only thing that tells two binaries of one version apart.
    expect(value, contains(AppInfo.buildNumber));

    await reveal(tester, find.text(value));
    await tester.longPress(find.text(value));
    await tester.pumpAndSettle();

    expect(written, [AppInfo.buildStamp]);
    expect(find.text(en.aboutCopied), findsOneWidget);
  });

  chatWidgetTest('the version row announces the copy action to a screen reader',
      (tester, harness) async {
    final handle = tester.ensureSemantics();
    await harness.pump(tester, const SettingsScreen());
    final en = await AppLocalizations.delegate.load(const Locale('en'));

    // A long press is invisible. Without the hint a screen-reader user has no
    // way to learn the action exists — there is no hover state on a settings
    // row to reveal it, and nothing is drawn.
    final row = tester.getSemantics(
      find.ancestor(
        of: find.text(en.settingsVersion),
        matching: find.byType(LevListRow),
      ),
    );
    expect(row.hint, contains(en.aboutVersionCopyHint));
    expect(
      row.getSemanticsData().hasAction(SemanticsAction.longPress),
      isTrue,
    );

    handle.dispose();
  });

  chatWidgetTest("the model's attribution comes from the manifest, not the code",
      (tester, harness) async {
    await harness.pump(tester, const SettingsScreen());

    // The descriptor's own string, shown verbatim and not translated: it is a
    // notice a licence asked for, not interface copy.
    expect(harness.model.attribution, isNotNull);
    expect(find.text(harness.model.attribution!), findsOneWidget);
  });

  chatWidgetTest('the licences row opens the licence page',
      (tester, harness) async {
    await harness.pump(tester, const SettingsScreen());
    final en = await AppLocalizations.delegate.load(const Locale('en'));

    await reveal(tester, find.text(en.aboutLicenses));
    await tester.tap(find.text(en.aboutLicenses));
    await tester.pumpAndSettle();

    // The obligation LEV cannot discharge anywhere else: distributed by file
    // transfer, it has no store listing to carry the notices (#2).
    expect(find.byType(LicensePage), findsOneWidget);
    expect(find.text(en.aboutLegalese), findsOneWidget);
  });

  chatWidgetTest("the licence page's own chrome is Hebrew in a Hebrew interface",
      (tester, harness) async {
    await harness.pump(tester, const SettingsScreen(),
        locale: const Locale('he'));
    final he = await AppLocalizations.delegate.load(const Locale('he'));

    await reveal(tester, find.text(he.aboutLicenses));
    await tester.tap(find.text(he.aboutLicenses));
    await tester.pumpAndSettle();

    // `LicensePage` is Flutter's, and its title, its back button and its
    // "N licences" counts come from `GlobalMaterialLocalizations` — not from
    // our ARB files. Without `flutter_localizations` wired and `he` supported,
    // the page opens in English inside a Hebrew interface, and nothing else in
    // the app would show it.
    final material = await GlobalMaterialLocalizations.delegate
        .load(const Locale('he'));
    expect(material.licensesPageTitle, isNot('Licenses'));
    expect(find.text(material.licensesPageTitle), findsWidgets);
    expect(
      Directionality.of(tester.element(find.byType(LicensePage))),
      TextDirection.rtl,
    );
  });

  chatWidgetTest('the support number is loaded, selectable, and never typed in',
      (tester, harness) async {
    await harness.pump(tester, const SettingsScreen());

    // The harness's stand-in for `assets/support/<lang>.json`, parsed the way
    // the app parses it. The point of the row is that both strings arrive from
    // that asset — the real number is reviewed on a schedule and has to be
    // fixable without a rebuild (#24), so nothing here may be a literal.
    final resource = LevSupportResources.parse(ChatHarness.supportResource);
    expect(find.text(resource.serviceName), findsOneWidget);

    // Selectable, because on a desktop with no dialler the only thing left to
    // do with a number is copy it — and a number that cannot be selected has to
    // be transcribed from the screen by hand.
    final phone = find.widgetWithText(SelectableText, resource.phone);
    expect(phone, findsOneWidget);
  });

  // Both themes and both sides of the 900px breakpoint. A widget test fails on
  // an overflow, so this is a real layout check rather than a smoke test — and
  // it is the check that would otherwise have to be made by hand on four
  // screenshots every time the section changes.
  for (final locale in const [Locale('he'), Locale('en')]) {
    for (final size in const [Size(400, 900), Size(1200, 900)]) {
      final layout = size.width < 900 ? 'mobile' : 'desktop';
      chatWidgetTest(
          'it lays out at $layout width in ${locale.languageCode}, '
          'light and dark', (tester, harness) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        for (final brightness in Brightness.values) {
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          await harness.pump(tester, const SettingsScreen(), locale: locale);

          final l10n = await AppLocalizations.delegate.load(locale);
          expect(find.text(l10n.settingsGroupAbout), findsOneWidget);
          expect(find.text(l10n.aboutFactDeletion), findsOneWidget);
          // Nothing may spill sideways: the four statements are the longest
          // running text on the screen, and they wrap rather than clip.
          expect(tester.takeException(), isNull);
        }
        tester.platformDispatcher.clearPlatformBrightnessTestValue();
      });
    }
  }

  chatWidgetTest('nothing in the section is red', (tester, harness) async {
    await harness.pump(tester, const SettingsScreen());

    // The destructive red reaches exactly one control in the product — the
    // confirm button of "delete all data" — and its force comes from nothing
    // else ever being that colour (#21).
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final colour = text.style?.color;
      if (colour == null) continue;
      expect(colour.r > colour.g * 1.8 && colour.r > colour.b * 1.8, isFalse,
          reason: 'a red-dominant colour on "${text.data}"');
    }
  });
}
