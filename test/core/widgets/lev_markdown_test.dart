import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lev/core/theme/app_theme.dart';
import 'package:lev/core/widgets/lev_widgets.dart';

/// The model writes markdown whether or not we asked it to. These pin what the
/// bubble does with it — and, just as much, what it leaves alone.
void main() {
  Future<void> pump(
    WidgetTester tester,
    String source, {
    bool isStreaming = false,
    ThemeData? theme,
  }) =>
      tester.pumpWidget(
        MaterialApp(
          theme: theme ?? LevTheme.light,
          home: Scaffold(
            body: LevMarkdownText(source, isStreaming: isStreaming),
          ),
        ),
      );

  /// The rendered text, markers and all, as a finder sees it.
  String plainText(WidgetTester tester) {
    final texts = tester.widgetList<Text>(find.byType(Text));
    return texts
        .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
        .join();
  }

  /// The style actually applied to the run containing [needle].
  TextStyle styleOf(WidgetTester tester, String needle) {
    final text = tester
        .widgetList<Text>(find.byType(Text))
        .firstWhere((t) => (t.textSpan?.toPlainText() ?? '').contains(needle));
    final match = (text.textSpan! as TextSpan)
        .children!
        .cast<TextSpan>()
        .firstWhere((s) => (s.text ?? '').contains(needle));
    return match.style!;
  }

  group('the shape of the output', () {
    // The load-bearing test. `find.text` matches a `Text` carrying a `textSpan`
    // via `toPlainText()`, but ignores a bare `RichText` — so plain prose must
    // come out as exactly one `Text.rich` with no wrapper, or every existing
    // assertion against a chat bubble stops matching.
    testWidgets('plain prose is one Text, byte-identical to the source',
        (tester) async {
      const source = 'one two three four five six';
      await pump(tester, source);

      expect(find.byType(Text), findsOneWidget);
      expect(find.text(source), findsOneWidget);
    });

    testWidgets('a multi-block source becomes a Column of blocks',
        (tester) async {
      await pump(tester, 'first\n\nsecond');

      expect(find.byType(Column), findsOneWidget);
      expect(find.text('first'), findsOneWidget);
      expect(find.text('second'), findsOneWidget);
    });
  });

  group('emphasis', () {
    testWidgets('bold loses its asterisks and gains its weight',
        (tester) async {
      await pump(tester, 'I hear **you**.');

      expect(find.text('I hear you.'), findsOneWidget);
      expect(styleOf(tester, 'you').fontWeight, FontWeight.w600);
    });

    testWidgets('inline code is styled and its backticks are gone',
        (tester) async {
      await pump(tester, 'try `rest` today');

      expect(find.text('try rest today'), findsOneWidget);
      expect(styleOf(tester, 'rest').backgroundColor,
          LevTheme.light.extension<LevColors>()!.line);
    });

    // The reason for booleans instead of a stack: an opener with no closer yet
    // takes effect immediately, so the arriving `**` changes nothing on screen.
    testWidgets('a dangling opener styles at once rather than waiting',
        (tester) async {
      await pump(tester, 'I feel **that');

      expect(find.text('I feel that'), findsOneWidget);
      expect(styleOf(tester, 'that').fontWeight, FontWeight.w600);
    });

    testWidgets('the closer arriving changes nothing', (tester) async {
      await pump(tester, 'I feel **that');
      final before = plainText(tester);

      await pump(tester, 'I feel **that**');

      expect(plainText(tester), before);
    });
  });

  group('what is not emphasis', () {
    testWidgets('arithmetic keeps its asterisk', (tester) async {
      await pump(tester, '5 * 3 = 15');

      expect(find.text('5 * 3 = 15'), findsOneWidget);
    });

    testWidgets('an identifier keeps its underscores', (tester) async {
      await pump(tester, 'snake_case_name');

      expect(find.text('snake_case_name'), findsOneWidget);
    });

    testWidgets('code is verbatim inside its backticks', (tester) async {
      await pump(tester, 'run `a * b` now');

      expect(find.text('run a * b now'), findsOneWidget);
    });
  });

  group('lists', () {
    testWidgets('bullets get a glyph and their text', (tester) async {
      await pump(tester, '- rest\n- water');

      expect(find.text('•'), findsNWidgets(2));
      expect(find.text('rest'), findsOneWidget);
      expect(find.text('water'), findsOneWidget);
    });

    // Silently renumbering would be the interface claiming the model was more
    // coherent than it actually was.
    testWidgets("numbered items keep the model's own numbers", (tester) async {
      await pump(tester, '3. third\n4. fourth');

      expect(find.text('3.'), findsOneWidget);
      expect(find.text('4.'), findsOneWidget);
      expect(find.text('1.'), findsNothing);
    });

    testWidgets('a heading renders as bold text, not as a heading scale',
        (tester) async {
      await pump(tester, '## Breathing\n\nSlowly.');

      expect(find.text('Breathing'), findsOneWidget);
      expect(styleOf(tester, 'Breathing').fontWeight, FontWeight.w600);
    });
  });

  group('everything outside the subset is literal', () {
    // An offline application must never draw something that looks tappable and
    // is not — the same reasoning that kept a website link off the support card.
    testWidgets('links and images are shown as written', (tester) async {
      await pump(tester, '[LEV](https://example.org)');

      expect(find.text('[LEV](https://example.org)'), findsOneWidget);
    });

    testWidgets('a table is shown as written', (tester) async {
      await pump(tester, '| a | b |');

      expect(find.text('| a | b |'), findsOneWidget);
    });

    // A backtick run of anything but one is literal, so a fence neither opens
    // a code span nor swallows the reply that follows it.
    testWidgets('a fence line does not swallow the rest of the reply',
        (tester) async {
      await pump(tester, '```\nkeep me\n```');

      expect(find.text('```\nkeep me\n```'), findsOneWidget);
    });

    testWidgets('an escaped marker survives as itself', (tester) async {
      await pump(tester, r'a \*literal\* star');

      expect(find.text('a *literal* star'), findsOneWidget);
    });
  });

  group('streaming', () {
    testWidgets('the caret is appended', (tester) async {
      await pump(tester, 'writing', isStreaming: true);

      expect(find.text('writing▌'), findsOneWidget);
    });

    // Without the clip, this prefix would show a literal `*` for one frame and
    // then snap when the second asterisk arrived.
    testWidgets('a marker run left dangling at the tail is clipped',
        (tester) async {
      await pump(tester, 'I feel *', isStreaming: true);

      expect(find.text('I feel ▌'), findsOneWidget);
    });

    testWidgets('a finished reply shows no caret', (tester) async {
      await pump(tester, 'writing');

      expect(find.text('writing'), findsOneWidget);
    });
  });

  testWidgets('colour comes from the theme, not from the widget',
      (tester) async {
    await pump(tester, 'hello', theme: LevTheme.dark);

    expect(
      styleOf(tester, 'hello').color,
      LevTheme.dark.extension<LevColors>()!.ink,
    );
  });
}
