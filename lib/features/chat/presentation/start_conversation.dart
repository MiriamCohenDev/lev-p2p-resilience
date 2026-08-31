import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/chat_providers.dart';
import '../../../core/di/llm_providers.dart';

/// Creates an empty conversation and returns its id.
///
/// Shared by Home's primary button and the history list's "new conversation",
/// which is the whole reason it is not a private method on either of them.
///
/// The conversation is created empty and named later, from its opening message —
/// see `ChatRepository.updateTitle`. The model is stamped now, so a later model
/// change stays traceable to the conversations held before it (§5.2.1).
///
/// **A model that cannot be resolved does not stop this.** If the weights are
/// missing or the device is below spec, `activeModelProvider` throws, and
/// refusing to create the conversation would turn that into a button that does
/// nothing with no explanation. The conversation is created without a model id
/// instead, and the chat screen reports the real failure — which is a screen the
/// design already specifies.
Future<String> startConversation(WidgetRef ref) async {
  final repository = await ref.read(chatRepositoryProvider.future);

  String? modelId;
  try {
    modelId = (await ref.read(activeModelProvider.future)).id;
  } on Object {
    modelId = null;
  }

  final conversation = await repository.createConversation(modelId: modelId);
  return conversation.id;
}
