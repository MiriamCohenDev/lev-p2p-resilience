import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/chat_providers.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/l10n/time_formats.dart';
import '../../../../core/layout/lev_shell.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/lev_widgets.dart';
import '../../domain/conversation.dart';

/// The saved conversations, wired to storage.
///
/// One widget for both places it appears — the mobile drawer and the desktop
/// column — because [LevConversationList] already decides which one it is in.
/// The search box is local state: it filters what is shown and touches nothing
/// stored.
class ConversationHistory extends ConsumerStatefulWidget {
  const ConversationHistory({
    super.key,
    this.selectedId,
    this.showSettings = false,
  });

  final String? selectedId;

  /// True in the drawer. On desktop, settings live at the bottom of the rail
  /// instead, so offering them twice would be noise.
  final bool showSettings;

  @override
  ConsumerState<ConversationHistory> createState() =>
      _ConversationHistoryState();
}

class _ConversationHistoryState extends ConsumerState<ConversationHistory> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final conversations = ref.watch(conversationsProvider);

    return conversations.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => LevEmptyState(
        title: l10n.chatLoadFailed,
        body: l10n.modelUnavailableBody,
        tone: LevTone.warning,
        icon: Icons.error_outline,
      ),
      data: (items) {
        final matches = _filter(items, l10n);
        final groups = _group(context, matches);

        // A filtered empty state explains and offers nothing to press; a
        // genuinely empty one invites. `LevConversationList` renders the second
        // when its groups are empty, so only the first is handled here.
        if (groups.isEmpty && _query.isNotEmpty) {
          return Column(
            children: [
              _searchField(l10n),
              Expanded(
                child: LevEmptyState(
                  title: l10n.conversationsSearchEmptyTitle,
                  body: l10n.conversationsSearchEmptyBody,
                ),
              ),
            ],
          );
        }

        return LevConversationList(
          groups: groups,
          selectedId: widget.selectedId,
          onSelect: (id) => context.go(AppRoutes.conversation(id)),
          onNewChat: _startConversation,
          onSearch: (value) => setState(() => _query = value),
          // The row hands back an id; the dialog needs the conversation, because
          // it prefills with the *stored* title and the row may be showing the
          // "untitled" placeholder instead of one.
          onRename: (id) => _rename(items.firstWhere((c) => c.id == id)),
          onDelete: _confirmDelete,
          onOpenSettings: widget.showSettings
              ? () => context.push(AppRoutes.settings)
              : null,
        );
      },
    );
  }

  /// The search field, duplicated only for the no-results state — which has to
  /// keep it on screen, since changing the search is the one thing to do there.
  Widget _searchField(AppLocalizations l10n) => Padding(
        padding: const EdgeInsetsDirectional.all(LevSpace.lg),
        child: TextField(
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            hintText: l10n.conversationsSearchHint,
            prefixIcon: const Icon(Icons.search, size: 18),
            isDense: true,
          ),
        ),
      );

  List<Conversation> _filter(
    List<Conversation> items,
    AppLocalizations l10n,
  ) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return items;
    return items
        .where(
          (c) => _titleOf(c, l10n).toLowerCase().contains(query),
        )
        .toList();
  }

  /// Groups by time, keeping the repository's ordering — most recently active
  /// first — so the headings come out in the order a person expects.
  List<LevConversationGroup> _group(
    BuildContext context,
    List<Conversation> items,
  ) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final groups = <String, List<LevConversationEntry>>{};

    for (final conversation in items) {
      final heading = conversationGroupHeading(
        context,
        conversation.updatedAt,
        now: now,
      );
      groups
          .putIfAbsent(heading, () => [])
          .add((id: conversation.id, title: _titleOf(conversation, l10n)));
    }

    return [
      for (final entry in groups.entries)
        (heading: entry.key, items: entry.value),
    ];
  }

  String _titleOf(Conversation conversation, AppLocalizations l10n) =>
      conversation.title.isEmpty ? l10n.conversationUntitled : conversation.title;

  /// Renaming, from the row's own menu.
  ///
  /// **Not confirmed, and correctly so.** A rename is reversible by renaming
  /// again; asking "are you sure?" before something undoable is how a
  /// confirmation stops being read by the time it guards a deletion.
  ///
  /// The title the chat derives from the opening message is only ever written
  /// when there is none yet, so a name chosen here is never quietly overwritten
  /// later.
  Future<void> _rename(Conversation conversation) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: conversation.title),
    );
    if (name == null || !mounted) return;

    final repository = await ref.read(chatRepositoryProvider.future);
    await repository.updateTitle(conversation.id, name);
  }

  /// Confirmed, because it is irreversible: deleting erases the messages
  /// outright rather than hiding them (technical-decisions #15), and there is no
  /// server and no backup to recover them from.
  ///
  /// The confirm button is **not** the destructive red. That is reserved for
  /// erasing the whole installation; one conversation is a smaller loss, and
  /// spending the red here would blunt it where it matters.
  Future<void> _confirmDelete(String conversationId) async {
    final l10n = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.conversationDeleteTitle),
        content: Text(l10n.conversationDeleteBody),
        actionsPadding: const EdgeInsetsDirectional.fromSTEB(
          LevSpace.lg,
          0,
          LevSpace.lg,
          LevSpace.lg,
        ),
        // `LevButton`, not Material's `TextButton`: every button in the product
        // comes from the component library. One `Row` rather than two entries,
        // because `AlertDialog.actions` is an `OverflowBar` and gives its
        // children no incoming width for `Expanded` to take.
        actions: [
          Row(
            children: [
              Expanded(
                child: LevButton(
                  label: l10n.cancel,
                  kind: LevButtonKind.secondary,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: LevSpace.md),
              Expanded(
                child: LevButton(
                  label: l10n.conversationDelete,
                  kind: LevButtonKind.secondary,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final repository = await ref.read(chatRepositoryProvider.future);
    await repository.deleteConversation(conversationId);
    if (!mounted) return;

    // Deleting the conversation you are looking at leaves you looking at
    // nothing — so it leaves you where the chat starts instead, at the draft.
    // Not merely tidier: without this the router stays on the deleted id, and
    // the tombstoned row still satisfies the messages' foreign key, so the
    // screen would go on accepting messages into a conversation that appears in
    // no list. Going to `/chat` is also what disposes the notifier and its
    // session.
    //
    // The same whether or not it was the last one left: there is no other
    // conversation to fall back to, and there does not need to be.
    if (conversationId != widget.selectedId) return;
    _leaveDrawer();
    if (!mounted) return;
    context.go(AppRoutes.chat);
  }

  /// "New conversation": the empty draft, not a new row.
  ///
  /// It creates nothing — a conversation exists once something has been said in
  /// it (technical-decisions #34) — so this is a navigation and nothing else.
  void _startConversation() {
    _leaveDrawer();
    context.go(AppRoutes.chat);
  }

  /// In the drawer, going somewhere closes it — the same rule picking a
  /// conversation follows.
  void _leaveDrawer() {
    if (Scaffold.maybeOf(context)?.hasDrawer ?? false) {
      Navigator.of(context).pop();
    }
  }
}

/// The rename dialog.
///
/// Stateful only so the save button can be disabled while the field is empty:
/// a conversation with no name at all is indistinguishable from every other
/// one in the list, which is the problem renaming exists to solve. The button
/// says *why* it is disabled rather than just sitting grey — a disabled control
/// with no explanation is a broken screen.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
    // Selected, not just placed: the common case is replacing the derived title
    // outright, and typing should do that without a clearing gesture first.
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initial.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _value => _controller.text.trim();

  void _submit() {
    if (_value.isEmpty) return;
    Navigator.of(context).pop(_value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.conversationRenameTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 1,
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(hintText: l10n.conversationRenameHint),
      ),
      actionsPadding: const EdgeInsetsDirectional.fromSTEB(
        LevSpace.lg,
        0,
        LevSpace.lg,
        LevSpace.lg,
      ),
      // One `Row`, for the same reason the delete dialog uses one:
      // `AlertDialog.actions` is an `OverflowBar` and hands its children no
      // incoming width for `Expanded` to take.
      actions: [
        Row(
          children: [
            Expanded(
              child: LevButton(
                label: l10n.cancel,
                kind: LevButtonKind.secondary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: LevSpace.md),
            Expanded(
              child: LevButton(
                label: l10n.save,
                onPressed: _value.isEmpty ? null : _submit,
                disabledHint: l10n.conversationRenameEmpty,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
