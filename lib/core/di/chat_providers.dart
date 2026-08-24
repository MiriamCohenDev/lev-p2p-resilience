import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/chat/data/drift_chat_repository.dart';
import '../../features/chat/domain/chat_repository.dart';
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
