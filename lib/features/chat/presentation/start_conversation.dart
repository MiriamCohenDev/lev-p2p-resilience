import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/chat_providers.dart';
import '../../../core/di/llm_providers.dart';

/// Creates a conversation and returns its id.
///
/// **This is the only place a conversation is created, and it has exactly one
/// caller: the draft screen's first send** (technical-decisions #34). Opening the
/// chat, pressing "new conversation" and Home's primary button all merely go to
/// `/chat`, which is a composer with nothing behind it yet — a conversation
/// exists once something has been said in it, and not before.
///
/// The conversation is created empty and named a moment later, from that opening
/// message — see `ChatRepository.updateTitle`. The model is stamped now, so a
/// later model change stays traceable to the conversations held before it
/// (§5.2.1).
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
