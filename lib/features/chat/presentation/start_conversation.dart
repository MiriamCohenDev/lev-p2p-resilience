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

/// The conversation `/chat` should open on: a blank one, ready to be spoken in.
///
/// Entering the chat with nothing chosen used to show an empty state with a
/// button; it opens a conversation instead, because the button asked the user to
/// confirm the thing they had already asked for by opening the chat.
///
/// **It reuses a blank conversation rather than minting one per visit.** The
/// chat is a permanent destination in the bar, so it is entered and left
/// repeatedly, and creating a row each time would fill the history — the one
/// list that has to stay navigable — with untitled conversations nobody said
/// anything in. Only the most recent one is considered: anything older has a
/// conversation on top of it, and reaching back past that would reopen
/// yesterday's abandoned start instead of beginning today's.
///
/// Emptiness is asked of the messages, not inferred from the empty title. The
/// title is derived from the opening message, so the two normally agree — but a
/// title is also something a person can set from the row's menu, and a renamed
/// conversation must not be mistaken for a blank one.
Future<String> openBlankConversation(WidgetRef ref) async {
  final repository = await ref.read(chatRepositoryProvider.future);

  final newest = await repository.latestConversation();
  if (newest != null && (await repository.messagesOf(newest.id)).isEmpty) {
    return newest.id;
  }

  return startConversation(ref);
}
