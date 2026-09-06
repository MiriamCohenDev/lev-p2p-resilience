import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lev/core/l10n/app_localizations.dart';
import 'package:lev/core/theme/app_theme.dart';
import 'package:lev/core/widgets/lev_logo.dart';
import 'package:lev/features/chat/presentation/chat_screen.dart';
import 'package:lev/features/home/presentation/home_screen.dart';

import '../../support/chat_harness.dart';

/// Desktop is not a wide phone (technical-decisions #21).
///
/// The same screen fills both layouts; what changes at 900px is the navigation
/// and whether the conversation list is a drawer or a permanent column.
void main() {
  /// Resizes the test surface and undoes it afterwards, so one case cannot leak
  /// its window into the next.
  void sized(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  chatWidgetTest('below the breakpoint: bottom navigation and a drawer',
      (tester, harness) async {
    sized(tester, const Size(420, 900));

    await harness.pump(tester, const ChatScreen());

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    // The list is behind the drawer rather than beside the conversation.
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.drawer, isNotNull);
  });

  chatWidgetTest('above the breakpoint: a rail and a permanent list column',
      (tester, harness) async {
    sized(tester, const Size(1200, 900));

    await harness.pump(tester, const ChatScreen());

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    // The search field belongs to the list, and it is on screen without
    // anything having to be opened.
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.conversationsSearchHint), findsOneWidget);
  });

  chatWidgetTest('settings is reachable from the foot of the rail',
      (tester, harness) async {
    sized(tester, const Size(1200, 900));

    await harness.pump(tester, const ChatScreen());

    // A regression guard. The control started life in `NavigationRail.trailing`
    // wrapped in an `Expanded` — the arrangement the Flutter sample shows — and
    // vanished: the rail puts its column inside a scroll view, so an `Expanded`
    // there has no bounded height to take. It collapsed to nothing and left
    // desktop with no way into Settings, and nothing failed.
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.byTooltip(l10n.settingsTitle), findsOneWidget);
  });

  group('the desktop list column can be put away', () {
    chatWidgetTest('the bar control collapses it and brings it back',
        (tester, harness) async {
      sized(tester, const Size(1200, 900));

      await harness.pump(tester, const ChatScreen());
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      double columnWidth() => tester
          .getSize(
            find.ancestor(
              of: find.text(l10n.conversationsSearchHint),
              matching: find.byType(ClipRect),
            ).first,
          )
          .width;

      expect(columnWidth(), greaterThan(0));

      await tester.tap(find.byTooltip(l10n.sideListHide));
      await tester.pumpAndSettle();

      // Collapsed, not unmounted: the list keeps its scroll and its search text
      // for when it comes back.
      expect(columnWidth(), 0);
      expect(find.text(l10n.conversationsSearchHint), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.sideListShow));
      await tester.pumpAndSettle();

      expect(columnWidth(), greaterThan(0));
    });

    chatWidgetTest('it stays put away when a conversation is opened',
        (tester, harness) async {
      // The reason the state is in a provider rather than in the shell:
      // `/chat/<id>` is a new page, so a `State` here would be discarded and the
      // column would spring back open on the one action still reachable while it
      // is collapsed.
      sized(tester, const Size(1200, 900));
      await harness.repository.createConversation(title: 'yesterday');

      await harness.pumpApp(tester);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.tap(find.byIcon(Icons.chat_bubble_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(l10n.sideListHide));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(l10n.conversationsNew));
      await tester.pumpAndSettle();

      expect(find.byTooltip(l10n.sideListShow), findsOneWidget);
      expect(find.byTooltip(l10n.sideListHide), findsNothing);
    });

    chatWidgetTest('a screen with no list column carries no control',
        (tester, harness) async {
      sized(tester, const Size(1200, 900));

      await harness.pump(tester, const HomeScreen());
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.byTooltip(l10n.sideListHide), findsNothing);
      expect(find.byTooltip(l10n.sideListShow), findsNothing);
    });

    chatWidgetTest('below the breakpoint there is nothing to collapse',
        (tester, harness) async {
      sized(tester, const Size(420, 900));

      await harness.pump(tester, const ChatScreen());
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // The drawer closes itself; a second control for the same thing would be
      // one more item in a bar that has no room for it.
      expect(find.byTooltip(l10n.sideListHide), findsNothing);
    });
  });

  group('the bar carries the logo only where the rail cannot', () {
    chatWidgetTest('below the breakpoint Home shows the mark',
        (tester, harness) async {
      sized(tester, const Size(420, 900));

      await harness.pump(tester, const HomeScreen());

      // No rail here, so the bar is the only place the product appears at all.
      expect(find.byType(LevLogo), findsOneWidget);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // Once — the bottom navigation's label, not a bar title.
      expect(find.text(l10n.navHome), findsOneWidget);
    });

    chatWidgetTest('above it the bar names the destination instead',
        (tester, harness) async {
      sized(tester, const Size(1200, 900));

      await harness.pump(tester, const HomeScreen());

      // Still one logo — the rail's. Two of them side by side is what this
      // avoids.
      expect(find.byType(LevLogo), findsOneWidget);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // Twice: the rail's destination label, and now the bar's title.
      expect(find.text(l10n.navHome), findsNWidgets(2));
    });
  });

  testWidgets('the breakpoint itself is read from the tokens', (tester) async {
    // 900 is a design token, not a number spelled into the layout. A test that
    // hardcoded it would agree with a typo.
    expect(LevBreakpoint.desktop, 900);
  });
}
