import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lev/core/l10n/app_localizations.dart';
import 'package:lev/core/widgets/lev_widgets.dart';
import 'package:lev/features/chat/domain/message.dart';
import 'package:lev/features/chat/presentation/widgets/chat_composer.dart';
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
    // The whole app, because the conversation is created on the way from the
    // draft into itself and `context.go` needs a router above the screen.
    await harness.pumpApp(tester);
    await tester.tap(find.text(l10n.homeStartChat));
    await tester.pumpAndSettle();

    // Home's button lands on the draft and creates nothing (#34); the message
    // is what creates it.
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    // A one-shot query, not `watchConversations().first`. Awaiting `.first`
    // cancels the subscription underneath, and a stream cancel does not resolve
    // under `fake_async` — see ChatHarness.unmount. A widget test that awaits it
    // hangs rather than failing.
    final conversations = await harness.conversations();
    expect(conversations, hasLength(1));
    expect(conversations.single.modelId, harness.model.id);
  }, replies: ['ok']);

  /// Opens a row's menu the way a phone does — the gesture that reaches it
  /// without a mouse.
  Future<void> openMenu(WidgetTester tester, String title) async {
    await tester.longPress(find.text(title));
    await tester.pumpAndSettle();
  }

  chatWidgetTest('deleting asks first, and does nothing if declined',
      (tester, harness) async {
    await harness.repository.createConversation(title: 'keep me');

    await pumpList(tester, harness);
    await openMenu(tester, 'keep me');
    // The menu entry, not the confirmation: deleting now takes two deliberate
    // steps rather than one long press.
    await tester.tap(find.text(l10n.conversationDelete));
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
    await openMenu(tester, 'goodbye');
    await tester.tap(find.text(l10n.conversationDelete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.conversationDelete).last);
    await tester.pumpAndSettle();

    expect(find.text('goodbye'), findsNothing);
    expect(find.text(l10n.conversationsEmptyTitle), findsOneWidget);
    // The row survives as a tombstone; its content does not
    // (technical-decisions #15).
    expect(await harness.repository.messagesOf(conversation.id), isEmpty);
  });

  /// Deleting the conversation you are looking at (technical-decisions #34).
  ///
  /// The whole app, because the assertion is about where you end up. These run
  /// on the mobile layout, so the list is the drawer and reaching it is a tap on
  /// the handle the `Scaffold` puts in the bar.
  group('deleting the conversation you are on', () {
    Future<void> openChat(WidgetTester tester) async {
      await tester.tap(find.text(l10n.navChat));
      await tester.pumpAndSettle();
    }

    /// The composer's field, not the drawer's search box — deleting a
    /// conversation you are not on leaves the drawer open, so a bare
    /// `find.byType(TextField)` is two widgets from then on.
    final composerField = find.descendant(
      of: find.byType(ChatComposer),
      matching: find.byType(TextField),
    );

    Future<void> send(WidgetTester tester, String text) async {
      await tester.enterText(composerField, text);
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
    }

    Future<void> deleteFromDrawer(WidgetTester tester, String title) async {
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      // Scoped to the drawer: a conversation's title is also its bar's title and
      // — since it is derived from the opening message — a bubble in it, so a
      // bare `find.text` here matches three widgets, all of them correct.
      await tester.longPress(
        find.descendant(of: find.byType(Drawer), matching: find.text(title)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.conversationDelete));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.conversationDelete).last);
      await tester.pumpAndSettle();
    }

    chatWidgetTest('lands back on the composer, with nothing behind it',
        (tester, harness) async {
      await harness.pumpApp(tester);
      await openChat(tester);
      await send(tester, 'goodbye');

      await deleteFromDrawer(tester, 'goodbye');

      // Exactly where entering the chat leaves you: somewhere to type, and no
      // conversation. Not the blank screen the deleted conversation used to
      // leave behind.
      expect(find.byType(ChatComposer), findsOneWidget);
      expect(find.text(l10n.conversationsEmptyTitle), findsWidgets);
      expect(find.text('goodbye'), findsNothing);

      // And writing again starts a second conversation rather than resurrecting
      // the tombstone.
      await send(tester, 'starting over');
      final live = (await harness.conversations())
          .where((c) => !c.isDeleted)
          .toList();
      expect(live, hasLength(1));
      expect(live.single.title, 'starting over');
    }, replies: ['ok']);

    chatWidgetTest('the same when it is the last one left',
        (tester, harness) async {
      await harness.pumpApp(tester);
      await openChat(tester);
      await send(tester, 'first');

      // A second, so the first delete has somewhere it could plausibly fall
      // back to — and does not.
      await openChat(tester);
      await send(tester, 'second');

      await deleteFromDrawer(tester, 'second');
      expect(find.byType(ChatComposer), findsOneWidget);
      expect(find.text('first'), findsNothing,
          reason: 'the newest survivor must not be opened in its place');

      // From the draft, so this one is a conversation we are *not* on — and it
      // is the last that existed. Nothing about that is a special case.
      await deleteFromDrawer(tester, 'first');
      expect(find.byType(ChatComposer), findsOneWidget);
      expect(find.text(l10n.conversationsEmptyTitle), findsWidgets);
    }, replies: ['ok']);

    chatWidgetTest('deleting one you are not on leaves you where you are',
        (tester, harness) async {
      await harness.pumpApp(tester);
      await openChat(tester);
      await send(tester, 'the other one');
      await openChat(tester);
      await send(tester, 'the open one');

      await deleteFromDrawer(tester, 'the other one');

      // Still in the conversation that was open, with its history intact.
      expect(find.text('the open one'), findsWidgets);
    }, replies: ['ok']);
  });

  group('finding the menu', () {
    /// Runs [body] on a platform that has a pointer.
    ///
    /// `flutter_test` reports Android by default — a phone, where the rules
    /// below are the other way round. Cleared inside the body rather than in
    /// `addTearDown`, which runs *after* the binding checks that no debug
    /// variable was left set.
    Future<void> withAPointer(Future<void> Function() body) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await body();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }

    /// Where there *is* a control, the tile keeps its space whether or not it
    /// is showing, so the title does not reflow under the pointer — which
    /// makes "is it there?" a question about `Visibility`, not about the tree.
    bool controlShown(WidgetTester tester) => tester
        .widget<Visibility>(
          find
              .ancestor(
                of: find.byTooltip(l10n.conversationActions),
                matching: find.byType(Visibility),
              )
              .first,
        )
        .visible;

    chatWidgetTest('a pointer resting on a row brings out its control',
        (tester, harness) async {
      await withAPointer(() async {
        await harness.repository.createConversation(title: 'under the mouse');
        await pumpList(tester, harness);

        expect(controlShown(tester), isFalse);

        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);
        await mouse.moveTo(tester.getCenter(find.text('under the mouse')));
        await tester.pumpAndSettle();

        expect(controlShown(tester), isTrue);
      });
    });

    chatWidgetTest('and it opens the same menu the gestures do',
        (tester, harness) async {
      await withAPointer(() async {
        await harness.repository.createConversation(title: 'tap the dots');
        await pumpList(tester, harness);

        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);
        await mouse.moveTo(tester.getCenter(find.text('tap the dots')));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip(l10n.conversationActions));
        await tester.pumpAndSettle();

        expect(find.text(l10n.conversationRename), findsOneWidget);
        expect(find.text(l10n.conversationDelete), findsOneWidget);
      });
    });

    chatWidgetTest('on a phone there is no control on the rows at all',
        (tester, harness) async {
      // Android, the binding's default. A control that no hover can reveal
      // would have to sit on every row always, and twelve of them down one
      // drawer pull harder than the twelve titles beside them. Every other
      // conversation list on a phone answers this with a long press, and so
      // does this one — which the delete and rename cases above exercise.
      await harness.repository.createConversation(title: 'on a phone');
      await pumpList(tester, harness);

      expect(find.byTooltip(l10n.conversationActions), findsNothing);

      await openMenu(tester, 'on a phone');
      expect(find.text(l10n.conversationRename), findsOneWidget);
    });
  });

  group('renaming', () {
    chatWidgetTest('replaces the derived title, prefilled and selected',
        (tester, harness) async {
      final conversation =
          await harness.repository.createConversation(title: 'derived name');

      await pumpList(tester, harness);
      await openMenu(tester, 'derived name');
      await tester.tap(find.text(l10n.conversationRename));
      await tester.pumpAndSettle();

      // Prefilled with what is stored, and selected whole — typing replaces it
      // rather than appending to it.
      final field = tester.widget<TextField>(find.byType(TextField).last);
      expect(field.controller!.text, 'derived name');
      expect(field.controller!.selection.textInside('derived name'),
          'derived name');

      await tester.enterText(find.byType(TextField).last, 'what I call it');
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.save));
      await tester.pumpAndSettle();

      expect(find.text('what I call it'), findsOneWidget);
      final stored = await harness.repository.findConversation(conversation.id);
      expect(stored!.title, 'what I call it');
    });

    chatWidgetTest('a name is required, and the button says why',
        (tester, harness) async {
      await harness.repository.createConversation(title: 'has a name');

      await pumpList(tester, harness);
      await openMenu(tester, 'has a name');
      await tester.tap(find.text(l10n.conversationRename));
      await tester.pumpAndSettle();

      // Whitespace is not a name. A conversation called ' ' is exactly the
      // column of identical rows renaming exists to break up.
      await tester.enterText(find.byType(TextField).last, '   ');
      await tester.pumpAndSettle();

      final save = tester.widget<LevButton>(
        find.widgetWithText(LevButton, l10n.save),
      );
      expect(save.onPressed, isNull);
      expect(save.disabledHint, l10n.conversationRenameEmpty);
    });
  });
}
