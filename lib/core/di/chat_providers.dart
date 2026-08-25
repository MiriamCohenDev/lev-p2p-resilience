import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/chat/data/drift_chat_repository.dart';
import '../../features/chat/data/provisional_prompt_builder.dart';
import '../../features/chat/domain/chat_repository.dart';
import '../../features/chat/domain/conversation.dart';
import '../../features/chat/domain/prompt_builder.dart';
import 'db_providers.dart';
import 'llm_providers.dart';

/// The chat feature's storage binding.
///
/// Registered in `core/di` rather than inside the feature, per technical-spec
/// §3.4: implementations are wired to domain interfaces here, so the
/// presentation layer resolves a [ChatRepository] and never learns that Drift
/// exists.
final chatRepositoryProvider = FutureProvider<ChatRepository>((ref) async {
  final database = await ref.watch(appDatabaseProvider.future);
  return DriftChatRepository(database.chatDao);
});

/// Every live conversation, most recently active first.
///
/// A `StreamProvider` over the repository's Drift stream, so the list re-renders
/// when a conversation is created, spoken in, or deleted, without anyone having
/// to remember to refresh it.
final conversationsProvider = StreamProvider<List<Conversation>>((ref) async* {
  final repository = await ref.watch(chatRepositoryProvider.future);
  yield* repository.watchConversations();
});

/// How a conversation is rendered into a prompt (technical-spec §5.2).
///
/// **Provisional binding.** Phase 2.3 replaces `ProvisionalPromptBuilder` with
/// the real one — versioned system prompt, per-family chat template, the
/// three-tier token budget and rolling-summary folding. It changes here and
/// nowhere else.
final promptBuilderProvider = Provider<PromptBuilder>((ref) {
  return ProvisionalPromptBuilder(ref.watch(tokenizerProvider));
});
