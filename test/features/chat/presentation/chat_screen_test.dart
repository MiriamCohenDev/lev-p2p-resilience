import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lev/core/l10n/app_localizations.dart';
import 'package:lev/features/chat/data/fake_llm_service.dart';
import 'package:lev/features/chat/domain/message_role.dart';
import 'package:lev/features/chat/presentation/chat_screen.dart';
import 'package:lev/core/widgets/lev_widgets.dart';

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

  /// The title carried by the harness's stand-in support resource.
  const supportTitle = 'You are not alone with this';

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

    expect(find.text(l10n.conversationsEmptyTitle), findsOneWidget);
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
    final streaming = tester.widgetList<LevBubble>(
      find.byType(LevBubble),
    );
    expect(streaming.any((b) => b.isStreaming), isTrue);

    await tester.pumpAndSettle();
    expect(find.text('one two three four five six'), findsOneWidget);
  },
      tokenDelay: const Duration(milliseconds: 10),
      replies: ['one two three four five six']);

  // What the test above promises in its name but never actually checks: not
  // merely that a bubble is marked as arriving, but that what it shows is a
  // *prefix* — the reply being written rather than pasted in whole.
  chatWidgetTest('the streaming bubble shows a prefix, never the whole reply',
      (tester, harness) async {
    final id = await conversationIn(harness);

    await harness.pump(tester, ChatScreen(conversationId: id));
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump(const Duration(milliseconds: 30));

    const reply = 'a slow steady sentence that takes a while to arrive';
    final bubble = find.byKey(const ValueKey('lev.chat.streaming'));
    expect(bubble, findsOneWidget);

    final shown = tester
        .widgetList<Text>(
          find.descendant(of: bubble, matching: find.byType(Text)),
        )
        .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
        .join()
        .replaceAll('▌', '');

    expect(shown, isNotEmpty, reason: 'the bubble must never render empty');
    expect(shown.length, lessThan(reply.length));
    expect(reply, startsWith(shown),
        reason: 'the bubble must show a prefix of the reply, not a jump');

    await tester.pumpAndSettle();
    expect(find.text(reply), findsOneWidget);
  },
      tokenDelay: const Duration(milliseconds: 10),
      replies: ['a slow steady sentence that takes a while to arrive']);

  chatWidgetTest("the model's markdown is rendered; the user's is not",
      (tester, harness) async {
    final id = await conversationIn(harness);

    await harness.pump(tester, ChatScreen(conversationId: id));
    await send(tester, '**not bold**');

    // Hers is quoted back exactly as she typed it.
    expect(find.text('**not bold**'), findsOneWidget);
    // His is read.
    expect(find.text('I hear you.'), findsOneWidget);
    expect(find.text('I hear **you**.'), findsNothing);
  }, replies: ['I hear **you**.']);

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
    expect(find.text(l10n.conversationsEmptyTitle), findsNothing);
  }, replies: ['ok']);

  chatWidgetTest('the prefill state is shown, not a blank screen',
      (tester, harness) async {
    final id = await conversationIn(harness);

    // Deliberately not settled: the assertion is about what is on screen
    // *during* the prefill, which is gone once the tree settles. §8 calls a
    // blank or frozen screen here a defect, so the wait must be labelled.
    await harness.pump(tester, ChatScreen(conversationId: id), settle: false);

    expect(find.text(l10n.chatPreparingSession), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text(l10n.chatPreparingSession), findsNothing,
        reason: 'it must clear once the session is open');
    expect(find.text(l10n.conversationsEmptyTitle), findsOneWidget);
  }, prefillDelay: const Duration(milliseconds: 200));

  group('failures', () {
    chatWidgetTest('a failure is reported rather than swallowed',
        (tester, harness) async {
      final id = await conversationIn(harness);

      await harness.pump(tester, ChatScreen(conversationId: id));
      await send(tester, 'hello');

      expect(find.text(l10n.chatTruncatedTitle), findsOneWidget);
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

    chatWidgetTest('asking again re-runs the turn without repeating the message',
        (tester, harness) async {
      final id = await conversationIn(harness);

      await harness.pump(tester, ChatScreen(conversationId: id));
      await send(tester, 'hello');

      expect(find.text(l10n.chatTruncatedTitle), findsOneWidget);

      await tester.tap(find.text(l10n.retry));
      await tester.pumpAndSettle();

      // The engine was asked a second time — the button is not a dismissal
      // wearing a retry's label.
      expect(harness.engine.received, hasLength(greaterThan(1)));

      // And the user's message was not appended again. A duplicate would
      // rewrite the conversation to say something she never said twice.
      final stored = await harness.repository.messagesOf(id);
      expect(stored.where((m) => m.text == 'hello'), hasLength(1));
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

  group('the safety layer (§5.2.4)', () {
    chatWidgetTest('surfaces its notice alongside the reply, not instead of it',
        (tester, harness) async {
      final id = await conversationIn(harness);

      await harness.pump(tester, ChatScreen(conversationId: id));
      await send(tester, 'I want to die');

      // Both. Replacing the answer with a canned notice would tell someone in
      // distress that saying the wrong thing gets them shut out.
      //
      // The text is the *support resource's* now, not the pattern file's
      // (technical-decisions #24): the pattern decides whether the card
      // appears, and the asset decides what it says and which number it dials.
      expect(find.text(supportTitle), findsOneWidget);
      expect(find.text('I hear you.'), findsOneWidget);

      // And the message itself is still a normal part of the conversation.
      final stored = await harness.repository.messagesOf(id);
      expect(stored.map((m) => m.text), ['I want to die', 'I hear you.']);
    }, replies: ['I hear you.']);

    chatWidgetTest('shows nothing on an ordinary message',
        (tester, harness) async {
      final id = await conversationIn(harness);

      await harness.pump(tester, ChatScreen(conversationId: id));
      await send(tester, 'I had a hard day');

      expect(find.text(supportTitle), findsNothing);
    }, replies: ['That sounds tiring.']);

    chatWidgetTest('clears the notice once the next message is ordinary',
        (tester, harness) async {
      final id = await conversationIn(harness);

      await harness.pump(tester, ChatScreen(conversationId: id));
      await send(tester, 'I want to die');
      expect(find.text(supportTitle), findsOneWidget);

      await send(tester, 'anyway, about work');

      // It belongs to the message that triggered it, not to the conversation.
      expect(find.text(supportTitle), findsNothing);
    }, replies: ['I hear you.', 'Tell me about work.']);
  });

  chatWidgetTest(
      'turns that fall out of the window are folded into the summary (§5.2.3)',
      (tester, harness) async {
    final id = await conversationIn(harness);

    await harness.pump(tester, ChatScreen(conversationId: id));

    // A budget this tight overflows within a few turns, so the fold is reached
    // without writing a conversation thousands of tokens long.
    for (var i = 0; i < 6; i++) {
      await send(tester, 'message number $i with some words in it');
    }

    final conversation = await harness.repository.findConversation(id);
    expect(conversation!.summary, isNotNull);
    expect(conversation.summary, isNotEmpty);
    // The summary records how far it accounts for, so the turns still carried
    // verbatim are not summarised twice.
    expect(conversation.summaryUpToMessageId, isNotNull);
  }, contextTokens: 128, replies: ['A short reply.']);

  chatWidgetTest('the summary is not written while the conversation still fits',
      (tester, harness) async {
    final id = await conversationIn(harness);

    await harness.pump(tester, ChatScreen(conversationId: id));
    await send(tester, 'hello');

    final conversation = await harness.repository.findConversation(id);
    expect(conversation!.summary, isNull);
  }, replies: ['ok']);

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
    expect(find.text(hebrew.conversationsEmptyTitle), findsOneWidget);
  }, replies: ['בסדר']);
}
