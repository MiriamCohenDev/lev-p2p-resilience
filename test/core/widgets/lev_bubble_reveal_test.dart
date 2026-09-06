import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lev/core/theme/app_theme.dart';
import 'package:lev/core/widgets/lev_widgets.dart';

/// The reply is revealed at reading speed rather than at whatever rate the
/// model happens to produce it.
///
/// The rule the whole design hangs on: **the ticker runs only while there is
/// backlog.** An animation that never ends hangs every `pumpAndSettle` in the
/// suite, so the first test here is the one that matters most.
void main() {
  Future<void> pumpBubble(
    WidgetTester tester,
    String text, {
    bool isStreaming = true,
    bool fromUser = false,
    bool disableAnimations = false,
  }) =>
      tester.pumpWidget(
        MaterialApp(
          theme: LevTheme.light,
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: disableAnimations),
            child: Scaffold(
              body: LevBubble(
                text: text,
                fromUser: fromUser,
                isStreaming: isStreaming,
              ),
            ),
          ),
        ),
      );

  /// What is on screen, caret stripped.
  String shown(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
      .join()
      .replaceAll('▌', '');

  const reply = 'Take a slow breath. There is no hurry here at all.';

  testWidgets('the ticker stops, so pumpAndSettle terminates', (tester) async {
    await pumpBubble(tester, reply);

    await tester.pumpAndSettle();

    expect(shown(tester), reply);
    expect(tester.hasRunningAnimations, isFalse,
        reason: 'a ticker still running here would hang the suite');
  });

  testWidgets('the reveal is progressive, not all at once', (tester) async {
    await pumpBubble(tester, reply);
    await tester.pump(const Duration(milliseconds: 16));

    final partial = shown(tester);

    expect(reply, startsWith(partial));
    expect(partial.length, lessThan(reply.length));
    expect(partial, isNotEmpty, reason: 'the bubble must never render empty');
  });

  testWidgets('a stored reply is shown whole, and schedules nothing',
      (tester) async {
    await pumpBubble(tester, reply, isStreaming: false);

    expect(shown(tester), reply);
    expect(tester.hasRunningAnimations, isFalse,
        reason: 'history must not type itself out again');
  });

  // Someone who types `**` means `**`.
  testWidgets('what the user wrote is never parsed', (tester) async {
    await pumpBubble(tester, '**hi**', isStreaming: false, fromUser: true);

    expect(find.text('**hi**'), findsOneWidget);
  });

  testWidgets('reduced motion reveals at once and never ticks',
      (tester) async {
    await pumpBubble(tester, reply, disableAnimations: true);

    expect(shown(tester), reply);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('growth continues where it left off rather than restarting',
      (tester) async {
    await pumpBubble(tester, 'Take a slow');
    await tester.pumpAndSettle();
    expect(shown(tester), 'Take a slow');

    await pumpBubble(tester, 'Take a slow breath.');
    await tester.pump(const Duration(milliseconds: 16));

    expect(shown(tester), startsWith('Take a slow'),
        reason: 'restarting would replay a sentence already read');
  });

  testWidgets('an unrelated replacement jumps to fully revealed',
      (tester) async {
    await pumpBubble(tester, 'the first reply');
    await tester.pumpAndSettle();

    await pumpBubble(tester, 'something else entirely');
    await tester.pump();

    expect(shown(tester), 'something else entirely');
  });

  testWidgets('disposing mid-reveal throws nothing', (tester) async {
    await pumpBubble(tester, reply);
    await tester.pump(const Duration(milliseconds: 16));

    await tester.pumpWidget(const SizedBox.shrink());

    expect(tester.takeException(), isNull);
  });
}
