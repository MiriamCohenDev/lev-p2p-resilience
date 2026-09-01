import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lev/core/theme/app_theme.dart';
import 'package:lev/core/widgets/lev_logo.dart';

/// The logo on screen has to be the logo on the launcher icon, and the word has
/// to appear only where the product is introducing itself.
void main() {
  Future<void> pumpLogo(WidgetTester tester, Widget logo) => tester.pumpWidget(
        MaterialApp(theme: LevTheme.light, home: Center(child: logo)),
      );

  group('which variant shows the word', () {
    testWidgets('mark is the symbol alone — no `LEV` anywhere in it',
        (tester) async {
      await pumpLogo(tester, const LevLogo.mark());

      // The rule the design states outright: bars carry the mark, never the
      // word. Repeating the name on every screen is how a name stops being read.
      expect(find.text('LEV'), findsNothing);
    });

    testWidgets('vertical and horizontal both set the word', (tester) async {
      for (final logo in const [LevLogo.vertical(), LevLogo.horizontal()]) {
        await pumpLogo(tester, logo);
        expect(find.text('LEV'), findsOneWidget);
      }
    });

    testWidgets('the word is set in the wordmark font, not the interface font',
        (tester) async {
      await pumpLogo(tester, const LevLogo.vertical());

      final style = tester.widget<Text>(find.text('LEV')).style!;
      expect(style.fontFamily, LevLogo.wordmarkFont);
      expect(style.fontFamily, isNot(levFontFamily));
    });

    test('and that font is actually shipped and declared', () {
      // The check above only proves the *name* asked for. Widget tests do not
      // load the application's fonts, so a family that is missing from
      // `pubspec.yaml` — or a file that never got committed — would render as
      // tofu in the real app and pass every test here. This is the failure mode
      // worth guarding, and it is a two-line read.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('family: ${LevLogo.wordmarkFont}'));

      final declared = RegExp(r'asset: (assets/fonts/Outfit[^\s]+)')
          .firstMatch(pubspec)
          ?.group(1);
      expect(declared, isNotNull, reason: 'no Outfit asset line in pubspec.yaml');
      expect(File(declared!).existsSync(), isTrue, reason: '$declared is missing');
    });
  });

  group('measurements derive from one height', () {
    test('the stacked word is half the mark; the inline word is 0.85 of it', () {
      // Vertical lets the symbol hold the screen, so the word sits under it
      // rather than competing.
      expect(LevLogo.fontSizeFor(76, LevLogoVariant.vertical), 38);
      expect(LevLogo.fontSizeFor(32, LevLogoVariant.horizontal), 32 * 0.85);
    });

    testWidgets('the mark takes exactly the height it is given', (tester) async {
      await pumpLogo(tester, const LevLogo.mark(height: 28));

      expect(tester.getSize(find.byType(LevLogo)), const Size(28, 28));
    });
  });

  group('the two drawings', () {
    test('small sizes get the heavier micro drawing', () {
      // At 20 logical pixels the regular 3.4 stroke thins out until the mark
      // reads as a smudge, which is what the pack's second file is for. The
      // sizes the app actually uses sit on the intended side of the line.
      expect(LevLogo.assetFor(21), endsWith('lev-mark-micro.svg'));
      expect(LevLogo.assetFor(LevLogo.microAtOrBelow), endsWith('-micro.svg'));
      expect(LevLogo.assetFor(28), endsWith('lev-mark.svg'));
    });

    test("both marks are shipped, and are the design's own files", () {
      for (final height in [20.0, 30.0]) {
        final file = File(LevLogo.assetFor(height));
        expect(file.existsSync(), isTrue, reason: '${file.path} is missing');

        final svg = file.readAsStringSync();
        // Two open strokes, not one closed outline: the shape of the whole logo
        // is that the paths do not meet. A file with one path, or with a `fill`
        // on the strokes, is not this mark.
        expect(RegExp(r'<path ').allMatches(svg), hasLength(2));
        expect(svg, contains('fill="none"'));
        expect(svg, contains('stroke-linecap="round"'));
        // `currentColor` is what the colour filter stands in for. A file with a
        // hardcoded stroke colour would still render — tinted — but the next
        // person to swap it in would not know why.
        expect(svg, contains('stroke="currentColor"'));
      }
    });
  });

  testWidgets('onColor paints the word white for a coloured ground',
      (tester) async {
    await pumpLogo(tester, const LevLogo.vertical(onColor: true));
    final onColour = tester.widget<Text>(find.text('LEV')).style!.color;

    await pumpLogo(tester, const LevLogo.vertical());
    final onCanvas = tester.widget<Text>(find.text('LEV')).style!.color;

    expect(onColour, LevColors.light.onPrimary);
    expect(onCanvas, LevColors.light.ink);
  });

  testWidgets('the lockup is announced once, as one image', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpLogo(tester, const LevLogo.vertical());

    // Without the `ExcludeSemantics` inside, the word would also be read as
    // text and a screen reader would say the name twice.
    expect(find.bySemanticsLabel('LEV'), findsOneWidget);
    handle.dispose();
  });

  group('static guards', () {
    /// Every Dart file under `lib/`, except the one allowed to break each rule.
    Iterable<File> sources({String? except}) => Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => except == null || !f.path.endsWith(except));

    void forbid(String pattern, String message, {String? except}) {
      final offences = <String>[];
      for (final file in sources(except: except)) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains(pattern)) offences.add('${file.path}:${i + 1}');
        }
      }
      expect(offences, isEmpty, reason: '$message\n${offences.join('\n')}');
    }

    test('no Material heart is left anywhere', () {
      // `Icons.favorite_border` is a *closed* outline; the logo is two open
      // strokes that stop short of meeting. Near enough to pass a glance and
      // wrong enough to notice beside the launcher icon — which is exactly how
      // it got shipped once already.
      forbid('Icons.favorite', 'use LevLogo');
    });

    test('nothing spells the wordmark by hand', () {
      forbid("Text('LEV')", 'use LevLogo.vertical or LevLogo.horizontal',
          except: 'lev_logo.dart');
    });

    test('nothing but LevLogo reaches for the branding assets', () {
      forbid('assets/branding/', 'the logo comes from LevLogo and nowhere else',
          except: 'lev_logo.dart');
    });

    test('the wordmark font is used by the logo and by nothing else', () {
      // It is subset to A–Z: any other text set in it would render as blanks,
      // and the logo's voice does not belong in ordinary copy.
      forbid('OutfitSemiBold', 'that font is the logo\'s alone',
          except: 'lev_logo.dart');
    });
  });
}
