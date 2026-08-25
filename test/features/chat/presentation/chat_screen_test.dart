import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lev/core/l10n/app_localizations.dart';
import 'package:lev/features/chat/data/fake_llm_service.dart';
import 'package:lev/features/chat/domain/message_role.dart';
import 'package:lev/features/chat/presentation/chat_screen.dart';
import 'package:lev/features/chat/presentation/widgets/message_bubble.dart';

import '../../../support/chat_harness.dart';

/// The §9 2.2 done-criteria, exercised end-to-end over the fake engine: a turn
/// streams, it persists, and the conversation survives being left and reopened.
void main() {
  late AppLocalizations l10n;
  late AppLocalizations hebrew;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
    hebrew = await AppLocalizations.delegate.load(const Locale('he'));
  });

  Future<String> conversationIn(ChatHarness harness) async =>
      (await harness.repository.createConversation()).id;

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
  }

  chatWidgetTest('an empty conversation invites a first message',
      (tester, harness) async {
    final id = await conversationIn(harness);

    await harness.pump(tester, ChatScreen(conversationId: id));

    expect(find.text(l10n.chatEmpty), findsOneWidget);
  });

  chatWidgetTest('a turn streams in and both sides persist',
      (tester, harness) async {
    final id = await conversationIn(harness);

    await harness.pump(tester, ChatScreen(conversationId: id));
    await send(tester, 'hello there');

    expect(find.text('hello there'), findsOneWidget);
    expect(find.text('I hear you.'), findsOneWidget);

    // The database is the real assertion — what is on screen could be state
    // that never reached disk, which is exactly the bug this guards.
    final stored = await harness.repository.messagesOf(id);
    expect(stored.map((m) => m.text), ['hello there', 'I hear you.']);
    expect(
      stored.map((m) => m.role),
      [MessageRole.user, MessageRole.assistant],
    );
  }, replies: ['I hear you.']);

  chatWidgetTest('the reply appears progressively, not all at once',
      (tester, harness) async {
    final id = await conversationIn(harness);

    await harness.pump(tester, ChatScreen(conversationId: id));

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.testTextInput.receiveAction(TextInputAction.send);

    // Part-way through: a bubble exists and is marked as still arriving.
    await tester.pump(const Duration(milliseconds: 35));
    final streaming = tester.widgetList<MessageBubble>(
      find.byType(MessageBubble),
    );
    expect(streaming.any((b) => b.isStreaming), isTrue);

    await tester.pumpAndSettle();
    expect(find.text('one two three four five six'), findsOneWidget);
  },
      tokenDelay: const Duration(milliseconds: 10),
      replies: ['one two three four five six']);

  chatWidgetTest('a multi-turn conversation keeps every turn',
      (tester, harness) async {
    final id = await conversationIn(harness);

    await harness.pump(tester, ChatScreen(conversationId: id));
    await send(tester, 'one');
    await send(tester, 'two');

    final stored = await harness.repository.messagesOf(id);
    expect(
      stored.map((m) => m.text),
      ['one', 'first reply', 'two', 'second reply'],
    );
  }, replies: ['first reply', 'second reply']);

  chatWidgetTest('the whole conversation is sent as the seed on reopen',
      (tester, harness) async {
    final id = await conversationIn(harness);

    await harness.pump(tester, ChatScreen(conversationId: id));
    await send(tester, 'remember this');

    harness.engine.received.clear();
    // Genuinely closed and reopened. Re-pumping the same tree would update it in
    // place, leaving the notifier — and its session — exactly where they were,
    // so the test would prove nothing. Replacing the screen drops the last
    // listener, which is what `autoDispose` acts on.
    await harness.pump(tester, const SizedBox.shrink());
    await harness.pump(tester, ChatScreen(conversationId: id));

    // §2.1's goal is a chat that responds to the *whole* conversation, so the
    // seed must carry what was said before.
    expect(harness.engine.received, isNotEmpty);
    expect(harness.engine.received.first.text, contains('remember this'));
  }, replies: ['ok']);

  chatWidgetTest('a stored conversation reopens with its history',
      (tester, harness) async {
    final id = await conversationIn(harness);

    await harness.pump(tester, ChatScreen(conversationId: id));
    await send(tester, 'said earlier');

    // Closed, then reopened — see the note on the seed test above.
    await harness.pump(tester, const SizedBox.shrink());
    await harness.pump(tester, ChatScreen(conversationId: id));

    expect(find.text('said earlier'), findsOneWidget);
    expect(find.text('ok'), findsOneWidget);
    expect(find.text(l10n.chatEmpty), findsNothing);
  }, replies: ['ok']);

  chatWidgetTest('the prefill state is shown, not a blank screen',
      (tester, harness) async {
    final id = await conversationIn(harness);

    // Deliberately not settled: the assertion is about what is on screen
    // *during* the prefill, which is gone once the tree settles. §8 calls a
    // blank or frozen screen here a defect, so the wait must be labelled.
    await harness.pump(tester, ChatScreen(conversationId: id), settle: false);

    expect(find.text(l10n.chatPreparing), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text(l10n.chatPreparing), findsNothing,
        reason: 'it must clear once the session is open');
    expect(find.text(l10n.chatEmpty), findsOneWidget);
  }, prefillDelay: const Duration(milliseconds: 200));

  group('failures', () {
    chatWidgetTest('a failure is reported rather than swallowed',
        (tester, harness) async {
      final id = await conversationIn(harness);

      await harness.pump(tester, ChatScreen(conversationId: id));
      await send(tester, 'hello');

      expect(find.text(l10n.chatFailed), findsOneWidget);
    }, mode: FakeEngineMode.failBeforeFirstToken);

    chatWidgetTest('a partial reply is kept when generation breaks',
        (tester, harness) async {
      final id = await conversationIn(harness);

      await harness.pump(tester, ChatScreen(conversationId: id));
      await send(tester, 'hello');

      final stored = await harness.repository.messagesOf(id);
      // What the user saw is real. Discarding it would erase part of the
      // conversation because the *rest* did not arrive.
      expect(stored, hasLength(2));
      expect(stored.last.role, MessageRole.assistant);
      expect(stored.last.text, isNotEmpty);
    },
        mode: FakeEngineMode.failMidGeneration,
        replies: [List.filled(30, 'word').join(' ')]);

    chatWidgetTest('a failure can be dismissed and the chat used again',
        (tester, harness) async {
      final id = await conversationIn(harness);

      await harness.pump(tester, ChatScreen(conversationId: id));
      await send(tester, 'hello');

      await tester.tap(find.text(l10n.dismiss));
      await tester.pumpAndSettle();

      expect(find.text(l10n.chatFailed), findsNothing);
    }, mode: FakeEngineMode.failBeforeFirstToken);

    chatWidgetTest('a stalled engine offers a way out', (tester, harness) async {
      final id = await conversationIn(harness);

      await harness.pump(tester, ChatScreen(conversationId: id));

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump(const Duration(milliseconds: 50));

      // The composer must not become a dead end. §8 makes a frozen screen a
      // defect, and a send button that quietly does nothing is the same defect.
      expect(find.byTooltip(l10n.chatStop), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.chatStop));
      await tester.pumpAndSettle();

      expect(find.byTooltip(l10n.chatSend), findsOneWidget);
    }, mode: FakeEngineMode.stall);
  });

  chatWidgetTest('the chat renders right-to-left in Hebrew',
      (tester, harness) async {
    final id = await conversationIn(harness);

    await harness.pump(
      tester,
      ChatScreen(conversationId: id),
      locale: const Locale('he'),
    );

    expect(
      Directionality.of(tester.element(find.byType(ChatScreen))),
      TextDirection.rtl,
    );
    expect(find.text(hebrew.chatEmpty), findsOneWidget);
  }, replies: ['בסדר']);
}
