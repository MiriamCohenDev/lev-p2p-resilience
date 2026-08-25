import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/chat_providers.dart';
import '../../../core/di/llm_providers.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../domain/conversation.dart';

/// Past conversations: open one, resume it, or delete it (technical-spec §9,
/// 2.2).
class ConversationListScreen extends ConsumerWidget {
  const ConversationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final conversations = ref.watch(conversationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.conversationsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startConversation(context, ref),
        icon: const Icon(Icons.add_comment_outlined),
        label: Text(l10n.conversationsNew),
      ),
      body: conversations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.chatLoadFailed, textAlign: TextAlign.center),
          ),
        ),
        data: (items) => items.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.conversationsEmpty,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.separated(
                // Clears the FAB, which would otherwise sit on the last entry.
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) => _ConversationTile(
                  conversation: items[index],
                ),
              ),
      ),
    );
  }

  Future<void> _startConversation(BuildContext context, WidgetRef ref) async {
    final repository = await ref.read(chatRepositoryProvider.future);
    final model = await ref.read(activeModelProvider.future);

    // Created empty and named later, from its opening message — see
    // `ChatRepository.updateTitle`. The model is stamped now, so a later model
    // change is traceable to the conversations held before it (§5.2.1).
    final conversation = await repository.createConversation(modelId: model.id);

    if (!context.mounted) return;
    context.go(AppRoutes.chat(conversation.id));
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final materialL10n = MaterialLocalizations.of(context);

    final title = conversation.title.isEmpty
        ? l10n.conversationUntitled
        : conversation.title;

    return ListTile(
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      // Formatted through MaterialLocalizations rather than a hardcoded
      // pattern, so the date reads correctly in Hebrew as well (#11).
      subtitle: Text(materialL10n.formatMediumDate(conversation.updatedAt)),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: l10n.conversationDelete,
        onPressed: () => _confirmDelete(context, ref),
      ),
      onTap: () => context.go(AppRoutes.chat(conversation.id)),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);

    // Confirmed because it is irreversible: deleting erases the messages
    // outright rather than hiding them (technical-decisions #15), and there is
    // no server and no backup to recover them from.
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
    await repository.deleteConversation(conversation.id);
  }
}
