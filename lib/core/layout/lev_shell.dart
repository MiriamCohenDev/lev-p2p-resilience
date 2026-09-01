import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/lev_widgets.dart';

/// The responsive navigation wrapper.
///
/// The decision it implements: **desktop is not a wide phone.**
///   • below 900px → bottom navigation, one screen at a time, lists in a drawer.
///   • above 900px → a `NavigationRail` on the start side (the right, in Hebrew)
///     plus a permanent list column.
///
/// The *same* screens fill both layouts. There is no second widget tree to
/// maintain, which is the whole reason this exists rather than a `HomeScreen`
/// and a `HomeScreenDesktop`.
///
/// It reads its own destination labels from [AppLocalizations] rather than
/// taking them as parameters: they are fixed for the whole application, and
/// making every screen pass the same three strings would be noise. #11 forbids
/// string *literals* in widgets, not localisation lookups.
enum LevDestination { home, chat, aid }

class LevShell extends StatelessWidget {
  const LevShell({
    super.key,
    required this.destination,
    required this.onDestinationChanged,
    required this.title,
    required this.body,
    this.sideList,
    this.appBarActions,
    this.appBarLeading,
    this.floatingAction,
    this.onOpenSettings,
  });

  final LevDestination destination;
  final ValueChanged<LevDestination> onDestinationChanged;

  /// The bar's title. A widget rather than a string because Home shows the
  /// wordmark with the heart beside it, not plain text.
  final Widget title;

  final Widget body;

  /// The list column. Permanent on desktop; becomes a drawer on mobile.
  /// `null` means this screen has no list (Home, for one).
  final Widget? sideList;

  final List<Widget>? appBarActions;

  /// Replaces the automatic drawer handle when a screen wants its own.
  final Widget? appBarLeading;

  /// Mobile only. Desktop has no culture of floating buttons — there the action
  /// sits at the top of the list column.
  final Widget? floatingAction;

  final VoidCallback? onOpenSettings;

  static IconData _icon(LevDestination d) => switch (d) {
        LevDestination.home => Icons.home_outlined,
        LevDestination.chat => Icons.chat_bubble_outline,
        LevDestination.aid => Icons.people_outline,
      };

  static String _label(AppLocalizations l10n, LevDestination d) => switch (d) {
        LevDestination.home => l10n.navHome,
        LevDestination.chat => l10n.navChat,
        LevDestination.aid => l10n.navAid,
      };

  @override
  Widget build(BuildContext context) {
    return LevBreakpoint.isWide(context) ? _buildWide(context) : _buildNarrow(context);
  }

  // ───────────────────────────── mobile ─────────────────────────────

  Widget _buildNarrow(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      // Under RTL Flutter opens the drawer from the start side — the right —
      // with no extra code.
      drawer: sideList == null
          ? null
          : Drawer(child: SafeArea(child: sideList!)),
      appBar: AppBar(
        title: title,
        leading: appBarLeading,
        actions: [
          ...?appBarActions,
          if (onOpenSettings != null && destination == LevDestination.home)
            IconButton(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.tune),
              tooltip: l10n.settingsTitle,
            ),
        ],
      ),
      body: body,
      floatingActionButton: floatingAction,
      bottomNavigationBar: NavigationBar(
        selectedIndex: LevDestination.values.indexOf(destination),
        onDestinationSelected: (i) =>
            onDestinationChanged(LevDestination.values[i]),
        destinations: [
          for (final d in LevDestination.values)
            NavigationDestination(
              icon: Icon(_icon(d)),
              label: _label(l10n, d),
            ),
        ],
      ),
    );
  }

  // ───────────────────────────── desktop ─────────────────────────────

  Widget _buildWide(BuildContext context) {
    final c = levColors(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Row(
        // Written start-to-end: rail, then the list column, then the content.
        // A `Row` lays its children out from the start edge, which is the
        // **right** under RTL — so this order puts the rail on the right in
        // Hebrew and on the left in English, with no branch here. Writing the
        // content first would have pinned the rail to the far edge and mirrored
        // the whole layout.
        children: [
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              border: BorderDirectional(end: BorderSide(color: c.line)),
            ),
            child: SafeArea(
              // Settings sits **below** the rail rather than in its `trailing`
              // slot. `NavigationRail` puts its column inside a scroll view so
              // it survives a short window, and an `Expanded` in there has no
              // bounded height to take — it collapses to nothing and the button
              // silently disappears, which is exactly what it did.
              child: Column(
                children: [
                  Expanded(
                    child: NavigationRail(
                      selectedIndex:
                          LevDestination.values.indexOf(destination),
                      onDestinationSelected: (i) =>
                          onDestinationChanged(LevDestination.values[i]),
                      labelType: NavigationRailLabelType.all,
                      leading: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          top: LevSpace.lg,
                          bottom: LevSpace.md,
                        ),
                        child: const LevLogo.mark(),
                      ),
                      destinations: [
                        for (final d in LevDestination.values)
                          NavigationRailDestination(
                            icon: Icon(_icon(d)),
                            label: Text(_label(l10n, d)),
                          ),
                      ],
                    ),
                  ),
                  if (onOpenSettings != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        bottom: LevSpace.lg,
                        top: LevSpace.sm,
                      ),
                      child: IconButton(
                        onPressed: onOpenSettings,
                        icon: const Icon(Icons.tune),
                        tooltip: l10n.settingsTitle,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (sideList != null)
            Container(
              width: 250,
              decoration: BoxDecoration(
                color: c.surface,
                border: BorderDirectional(end: BorderSide(color: c.line)),
              ),
              child: SafeArea(child: sideList!),
            ),
          // The content takes whatever is left.
          Expanded(
            child: Column(
              children: [
                _DesktopBar(title: title, actions: appBarActions),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopBar extends StatelessWidget {
  const _DesktopBar({required this.title, this.actions});

  final Widget title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final c = levColors(context);
    return Container(
      height: 56,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: LevSpace.xl),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          DefaultTextStyle.merge(
            style: Theme.of(context).textTheme.titleLarge!,
            child: title,
          ),
          const Spacer(),
          ...?actions,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// The conversation list — one widget, in the drawer and in the column
// ═══════════════════════════════════════════════════════════════════════

/// A group of conversations under one time heading.
typedef LevConversationGroup = ({String heading, List<LevConversationEntry> items});

typedef LevConversationEntry = ({String id, String title});

/// The conversation list.
///
/// **One widget, two behaviours.** Whether picking a conversation closes a
/// drawer is decided by `Scaffold.maybeOf(context)?.hasDrawer` — that is the
/// entire difference between the mobile drawer and the desktop column, and it is
/// what saves maintaining two separate screens.
class LevConversationList extends StatelessWidget {
  const LevConversationList({
    super.key,
    required this.groups,
    required this.selectedId,
    required this.onSelect,
    required this.onNewChat,
    this.onSearch,
    this.onRename,
    this.onDelete,
    this.onOpenSettings,
  });

  /// Grouped by time — today · the last 7 days · earlier. A supportive
  /// conversation is remembered by *when* it happened, not by its title.
  final List<LevConversationGroup> groups;

  final String? selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onNewChat;
  final ValueChanged<String>? onSearch;

  /// What a row's own menu offers. Both are optional; a list given neither has
  /// no menu at all, and its rows lose the control that opens one.
  ///
  /// The design draws no per-row controls, and a *visible* delete on every row
  /// would put a destructive action twelve times over in the quietest list in
  /// the product. Neither is droppable, though: this is a privacy application,
  /// and being unable to remove a conversation would be a real loss.
  ///
  /// So they sit behind one menu, reached the way the platform reaches menus:
  /// on a phone, a long press — the same gesture every other conversation list
  /// there uses. Where there is a pointer, that plus a control the row shows
  /// under it, a right-click, and the keyboard, which reveals the control on
  /// focus and closes the gap left open in #22.
  final ValueChanged<String>? onRename;
  final ValueChanged<String>? onDelete;

  /// Shown in the drawer only (mobile). On desktop, settings live at the bottom
  /// of the rail.
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final c = levColors(context);
    final l10n = AppLocalizations.of(context);
    final inDrawer = Scaffold.maybeOf(context)?.hasDrawer ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.all(LevSpace.lg),
          child: Column(
            children: [
              TextField(
                onSubmitted: onSearch,
                onChanged: onSearch,
                decoration: InputDecoration(
                  hintText: l10n.conversationsSearchHint,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                ),
              ),
              const SizedBox(height: LevSpace.md),
              LevButton(
                label: l10n.conversationsNew,
                icon: Icons.add,
                onPressed: onNewChat,
              ),
            ],
          ),
        ),
        Divider(color: c.line, height: 1),
        Expanded(
          child: groups.isEmpty
              ? LevEmptyState(
                  title: l10n.conversationsEmptyTitle,
                  body: l10n.conversationsEmptyBody,
                )
              : ListView(
                  children: [
                    for (final group in groups) ...[
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          LevSpace.lg,
                          LevSpace.lg,
                          LevSpace.lg,
                          LevSpace.xs + 2,
                        ),
                        child: Text(
                          group.heading,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      for (final conversation in group.items)
                        _ConversationTile(
                          title: conversation.title,
                          selected: conversation.id == selectedId,
                          onTap: () {
                            onSelect(conversation.id);
                            // In the drawer, picking closes it. In the permanent
                            // column there is nothing to close.
                            if (inDrawer) Navigator.of(context).pop();
                          },
                          onRename: onRename == null
                              ? null
                              : () => onRename!(conversation.id),
                          onDelete: onDelete == null
                              ? null
                              : () => onDelete!(conversation.id),
                        ),
                    ],
                  ],
                ),
        ),
        if (onOpenSettings != null) ...[
          Divider(color: c.line, height: 1),
          LevListRow(
            title: l10n.settingsTitle,
            onTap: onOpenSettings,
            showDivider: false,
          ),
        ],
      ],
    );
  }
}

/// One conversation in the list.
///
/// **The row answers the pointer before it is clicked.** It used to be flat
/// until it was selected, so on a column of a dozen near-identical titles there
/// was no way to tell which one was about to be opened — the ground changes
/// under the cursor now, and under keyboard focus, which is the same question
/// asked without a mouse.
///
/// Its own actions live behind a menu on the row rather than as controls on it:
/// a delete button visible on every row would put a destructive action in the
/// quietest list in the product, twelve times over. **How the menu is reached
/// is the platform's own idiom** — the control that appears under the pointer
/// where there is one, a long press where there is not.
class _ConversationTile extends StatefulWidget {
  const _ConversationTile({
    required this.title,
    required this.selected,
    required this.onTap,
    this.onRename,
    this.onDelete,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  bool _pointerOn = false;
  bool _focused = false;
  bool _menuOpen = false;

  bool get _hasMenu => widget.onRename != null || widget.onDelete != null;

  /// Whether the row is the one being addressed right now — by a pointer, by
  /// the keyboard, or by its own menu standing open over it.
  bool get _active => _pointerOn || _focused || _menuOpen;

  /// Whether this platform has a pointer that can reveal the control.
  ///
  /// A phone has none, so the control would have to be shown always — twelve
  /// of them, in one column, in a drawer the width of a thumb. Tried, and the
  /// stripe of dots pulled the eye harder than the titles it was sitting next
  /// to. Conversation lists on phones do not carry one: a long press is the
  /// gesture for a row's own actions, and it is the one this uses.
  bool get _hasPointer => switch (defaultTargetPlatform) {
        TargetPlatform.android ||
        TargetPlatform.iOS ||
        TargetPlatform.fuchsia =>
          false,
        _ => true,
      };

  Future<void> _openMenu(BuildContext anchor, {Offset? at}) async {
    final l10n = AppLocalizations.of(context);

    // Held open past the menu itself: without this the row would fall back to
    // flat the moment the pointer left it for the menu, and the menu would be
    // hanging off nothing.
    setState(() => _menuOpen = true);
    await showLevMenu(
      anchor: anchor,
      at: at,
      actions: [
        if (widget.onRename != null)
          (
            icon: Icons.edit_outlined,
            label: l10n.conversationRename,
            onSelected: widget.onRename!,
          ),
        if (widget.onDelete != null)
          (
            icon: Icons.delete_outline,
            label: l10n.conversationDelete,
            onSelected: widget.onDelete!,
          ),
      ],
    );
    if (mounted) setState(() => _menuOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = levColors(context);
    final l10n = AppLocalizations.of(context);

    return Semantics(
      selected: widget.selected,
      button: true,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (on) => setState(() => _pointerOn = on),
        onFocusChange: (on) => setState(() => _focused = on),
        // The same menu, from the two gestures that have always meant "more":
        // a long press where there is no mouse, a right-click where there is.
        onLongPress: _hasMenu ? () => _openMenu(context) : null,
        onSecondaryTapDown:
            _hasMenu ? (d) => _openMenu(context, at: d.globalPosition) : null,
        child: AnimatedContainer(
          duration: reduceMotion(context) ? Duration.zero : LevMotion.fast,
          curve: LevMotion.curve,
          constraints: const BoxConstraints(minHeight: LevSpace.minTouch),
          padding: const EdgeInsetsDirectional.only(start: LevSpace.lg),
          // Selected wins over hover: which conversation is open is the more
          // important of the two facts, and a hovered selected row that lost
          // its turquoise would read as a deselection.
          color: widget.selected
              ? c.primarySoft
              : _active
                  ? c.hover
                  : null,
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    vertical: LevSpace.md,
                  ),
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: widget.selected ? c.primary : c.ink,
                          fontWeight: widget.selected
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                  ),
                ),
              ),
              if (_hasMenu && _hasPointer)
                // The space is held whether or not the control is showing, so
                // the title does not shorten and re-ellipsise under the
                // pointer. Hidden, it is out of the tab order and out of the
                // screen reader too — `Visibility` drops both.
                Visibility(
                  visible: _active,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: Builder(
                    builder: (button) => IconButton(
                      onPressed: () => _openMenu(button),
                      icon: const Icon(Icons.more_horiz, size: 18),
                      tooltip: l10n.conversationActions,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: LevSpace.minTouch,
                        height: LevSpace.minTouch,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
