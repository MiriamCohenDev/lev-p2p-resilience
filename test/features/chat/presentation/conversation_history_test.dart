import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lev/core/l10n/app_localizations.dart';
import 'package:lev/features/chat/domain/message.dart';
import 'package:lev/features/chat/presentation/widgets/conversation_history.dart';

import '../../../support/chat_harness.dart';

/// Browsing past conversations (technical-spec §9, 2.2).
///
/// The list used to be a screen of its own; it is now the drawer on mobile and
/// the permanent column on desktop, and the same widget in both
/// (technical-decisions #22).
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Future<void> pumpList(WidgetTester tester, ChatHarness harness) =>
      harness.pump(
        tester,
        const Scaffold(body: ConversationHistory()),
      );

  chatWidgetTest('says so when there is nothing yet', (tester, harness) async {
    await pumpList(tester, harness);

    // The promise is repeated at exactly the moment the user is about to write
    // the first thing, which is where the sentence is worth something.
    expect(find.text(l10n.conversationsEmptyTitle), findsOneWidget);
    expect(find.text(l10n.conversationsEmptyBody), findsOneWidget);
  });

  chatWidgetTest('groups by time, most recently active first',
      (tester, harness) async {
    final now = DateTime.now();

    final quiet = await harness.repository.createConversation(title: 'quiet');
    final busy = await harness.repository.createConversation(title: 'busy');
    await harness.repository.append(
      Message.fromUserInput(
        conversationId: quiet.id,
        text: 'once',
        createdAt: now.subtract(const Duration(minutes: 10)),
      ),
    );
    await harness.repository.append(
      Message.fromUserInput(
        conversationId: busy.id,
        text: 'later',
        createdAt: now,
      ),
    );

    await pumpList(tester, harness);

    expect(find.text(l10n.conversationGroupToday), findsOneWidget);
    // Both under one heading, in the repository's order.
    final busyY = tester.getTopLeft(find.text('busy')).dy;
    final quietY = tester.getTopLeft(find.text('quiet')).dy;
    expect(busyY, lessThan(quietY));
  });

  chatWidgetTest('a conversation with no message yet is labelled, not blank',
      (tester, harness) async {
    await harness.repository.createConversation();

    await pumpList(tester, harness);

    expect(find.text(l10n.conversationUntitled), findsOneWidget);
  });

  chatWidgetTest('searching that matches nothing explains rather than empties',
      (tester, harness) async {
    await harness.repository.createConversation(title: 'about Shabbat');
    await pumpList(tester, harness);

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();

    expect(find.text(l10n.conversationsSearchEmptyTitle), findsOneWidget);
    // A filtered empty state gets no action: there is nothing to do in it but
    // change the search, so a button there would be noise.
    expect(find.text(l10n.conversationsNew), findsNothing);
  });

  chatWidgetTest('creating a conversation stamps the active model',
      (tester, harness) async {
    // The whole app, because creating one navigates into it and `context.go`
    // needs a router above the screen.
    await harness.pumpApp(tester);
    await tester.tap(find.text(l10n.homeStartChat));
    await tester.pumpAndSettle();

    // A one-shot query, not `watchConversations().first`. Awaiting `.first`
    // cancels the subscription underneath, and a stream cancel does not resolve
    // under `fake_async` — see ChatHarness.unmount. A widget test that awaits it
    // hangs rather than failing.
    final conversations = await harness.conversations();
    expect(conversations, hasLength(1));
    expect(conversations.single.modelId, harness.model.id);
  }, replies: ['ok']);

  chatWidgetTest('deleting asks first, and does nothing if declined',
      (tester, harness) async {
    await harness.repository.createConversation(title: 'keep me');

    await pumpList(tester, harness);
    await tester.longPress(find.text('keep me'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.conversationDeleteTitle), findsOneWidget);

    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();

    expect(find.text('keep me'), findsOneWidget);
  });

  chatWidgetTest('deleting removes the conversation and erases its messages',
      (tester, harness) async {
    final conversation =
        await harness.repository.createConversation(title: 'goodbye');
    await harness.repository.append(
      Message.fromUserInput(
        conversationId: conversation.id,
        text: 'private',
        createdAt: DateTime.now(),
      ),
    );

    await pumpList(tester, harness);
    await tester.longPress(find.text('goodbye'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.conversationDelete).last);
    await tester.pumpAndSettle();

    expect(find.text('goodbye'), findsNothing);
    expect(find.text(l10n.conversationsEmptyTitle), findsOneWidget);
    // The row survives as a tombstone; its content does not
    // (technical-decisions #15).
    expect(await harness.repository.messagesOf(conversation.id), isEmpty);
  });
}
