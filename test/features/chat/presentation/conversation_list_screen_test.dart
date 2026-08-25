import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lev/core/l10n/app_localizations.dart';
import 'package:lev/features/chat/domain/message.dart';
import 'package:lev/features/chat/presentation/conversation_list_screen.dart';

import '../../../support/chat_harness.dart';

/// Browsing past conversations (technical-spec §9, 2.2): open one, resume it,
/// delete it.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  chatWidgetTest('says so when there is nothing yet', (tester, harness) async {
    await harness.pump(tester, const ConversationListScreen());

    expect(find.text(l10n.conversationsEmpty), findsOneWidget);
  });

  chatWidgetTest('lists conversations, most recently active first',
      (tester, harness) async {
    final at = DateTime.utc(2026, 8, 25, 10);

    final quiet = await harness.repository.createConversation(title: 'quiet');
    final busy = await harness.repository.createConversation(title: 'busy');
    await harness.repository.append(
      Message.fromUserInput(
        conversationId: quiet.id,
        text: 'once',
        createdAt: at,
      ),
    );
    await harness.repository.append(
      Message.fromUserInput(
        conversationId: busy.id,
        text: 'later',
        createdAt: at.add(const Duration(minutes: 5)),
      ),
    );

    await harness.pump(tester, const ConversationListScreen());

    final titles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tile) => (tile.title! as Text).data);
    expect(titles, ['busy', 'quiet']);
  });

  chatWidgetTest('a conversation with no message yet is labelled, not blank',
      (tester, harness) async {
    await harness.repository.createConversation();

    await harness.pump(tester, const ConversationListScreen());

    expect(find.text(l10n.conversationUntitled), findsOneWidget);
  });

  chatWidgetTest('creating a conversation stamps the active model',
      (tester, harness) async {
    // The whole app, because creating a conversation navigates into it and
    // `context.go` needs a router above the screen.
    await harness.pumpApp(tester);
    await tester.tap(find.text(l10n.homeOpenChat));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.conversationsNew));
    await tester.pumpAndSettle();

    // A one-shot query, not `watchConversations().first`. Awaiting `.first`
    // cancels the subscription underneath, and a stream cancel does not resolve
    // under `fake_async` — see ChatHarness.unmount. A widget test that awaits it
    // hangs rather than failing.
    final conversations = await harness.conversations();
    expect(conversations, hasLength(1));
    expect(conversations.single.modelId, harness.model.id);
  });

  chatWidgetTest('deleting asks first, and does nothing if declined',
      (tester, harness) async {
    await harness.repository.createConversation(title: 'keep me');

    await harness.pump(tester, const ConversationListScreen());
    await tester.tap(find.byTooltip(l10n.conversationDelete));
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
        createdAt: DateTime.utc(2026, 8, 25),
      ),
    );

    await harness.pump(tester, const ConversationListScreen());
    await tester.tap(find.byTooltip(l10n.conversationDelete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.conversationDelete).last);
    await tester.pumpAndSettle();

    expect(find.text('goodbye'), findsNothing);
    expect(find.text(l10n.conversationsEmpty), findsOneWidget);
    expect(await harness.repository.messagesOf(conversation.id), isEmpty);
  });
}
