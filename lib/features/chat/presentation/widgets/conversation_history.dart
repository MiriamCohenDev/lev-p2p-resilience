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
import '../start_conversation.dart';

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
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.conversationDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final repository = await ref.read(chatRepositoryProvider.future);
    await repository.deleteConversation(conversationId);
  }

  Future<void> _startConversation() async {
    final id = await startConversation(ref);
    if (!mounted) return;
    // In the drawer, creating one closes it — the same rule picking one follows.
    final navigator = Navigator.of(context);
    if (Scaffold.maybeOf(context)?.hasDrawer ?? false) navigator.pop();
    if (!mounted) return;
    context.go(AppRoutes.conversation(id));
  }
}
