import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/chat/data/drift_chat_repository.dart';
import '../../features/chat/domain/chat_repository.dart';
import '../../features/chat/domain/conversation.dart';
import 'db_providers.dart';

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

// The prompt layer itself lives in `prompt_providers.dart` — it has enough
// moving parts (system prompt, chat templates, budget, safety) to be its own
// file rather than a tail on this one.
