import 'dart:async';

import 'package:characters/characters.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/chat_providers.dart';
import '../../../core/di/llm_providers.dart';
import '../../../llm/model_descriptor.dart';
import '../domain/chat_repository.dart';
import '../domain/llm_service.dart';
import '../domain/message.dart';
import '../domain/prompt_builder.dart';
import 'chat_state.dart';

/// One open conversation, with its live [LlmSession] (technical-spec §5.1).
///
/// `autoDispose` is load-bearing rather than a default: §5.1 says closing a
/// conversation disposes its session, and the session owns the engine's KV
/// cache. Keeping it alive after the screen is gone would hold that memory for
/// every conversation the user ever opened, which §8's battery-and-memory
/// requirement rules out.
final chatNotifierProvider =
    AsyncNotifierProvider.autoDispose.family<ChatNotifier, ChatState, String>(
  ChatNotifier.new,
);

class ChatNotifier extends AsyncNotifier<ChatState> {
  ChatNotifier(this.conversationId);

  final String conversationId;

  late final ChatRepository _repository;
  late final PromptBuilder _promptBuilder;
  late final ModelDescriptor _model;
  LlmSession? _session;

  /// The generation in flight. Held so it can be cancelled — by the user, or by
  /// the notifier being disposed out from under it.
  StreamSubscription<String>? _generation;

  /// Completes when the turn in flight is finished, however it finishes.
  ///
  /// A field rather than a local inside [send] because a cancelled turn ends
  /// somewhere else entirely: the stream is dropped, so neither `onDone` nor
  /// `onError` ever fires, and a completer that only those two could reach would
  /// leave every cancelled `send` pending forever.
  Completer<void>? _turn;

  @override
  Future<ChatState> build() async {
    _repository = await ref.watch(chatRepositoryProvider.future);

    final conversation = await _repository.findConversation(conversationId);
    if (conversation == null) {
      throw StateError('conversation $conversationId does not exist');
    }

    // One subscription, and the initial history comes out of it.
    //
    // Reading the history separately and *then* subscribing leaves a window in
    // which an append lands in neither — the snapshot has already been taken and
    // the stream is not yet listening. Letting the subscription's first event be
    // the snapshot closes that window by construction.
    final completer = Completer<List<Message>>();
    final subscription =
        _repository.watchMessages(conversationId).listen((messages) {
      if (!completer.isCompleted) {
        completer.complete(messages);
        return;
      }
      final current = state.value;
      if (current != null) {
        state = AsyncData(current.copyWith(messages: messages));
      }
    });
    ref.onDispose(subscription.cancel);
    ref.onDispose(_detachGeneration);

    final history = await completer.future;

    final llm = await ref.watch(llmServiceProvider.future);
    _model = await ref.watch(activeModelProvider.future);
    _promptBuilder = ref.watch(promptBuilderProvider);

    // The one prefill §5.1 describes. The screen shows `AsyncLoading` across
    // it; `isPrefilling` covers a re-prefill on an already-built state.
    final seed = _promptBuilder.buildSeed(conversation, history, _model);
    final session = await llm.openSession(seed: seed);
    _session = session;
    ref.onDispose(session.dispose);

    return ChatState(messages: history);
  }

  /// Sends [text] and streams the reply.
  Future<void> send(String text) async {
    final trimmed = text.trim();
    final current = state.value;
    if (trimmed.isEmpty || current == null || current.isBusy) return;

    final session = _session;
    if (session == null) return;

    state = AsyncData(
      current.copyWith(isTyping: true, streamingText: '', clearFailure: true),
    );

    final userMessage = Message.fromUserInput(
      conversationId: conversationId,
      text: trimmed,
    );
    await _repository.append(userMessage);
    await _titleFrom(trimmed);

    final turn = _promptBuilder.buildTurn(userMessage, _model);
    final buffer = StringBuffer();
    final completed = Completer<void>();
    _turn = completed;

    _generation = session.send(turn).listen(
      (token) {
        buffer.write(token);
        final live = state.value;
        if (live != null) {
          state = AsyncData(live.copyWith(streamingText: buffer.toString()));
        }
      },
      // A partial reply is what the user saw, so it is persisted rather than
      // discarded; the failure says the *rest* is not coming.
      onError: (Object error) =>
          _finishGeneration(buffer.toString(), failure: error),
      onDone: () => _finishGeneration(buffer.toString()),
      cancelOnError: true,
    );

    await completed.future;
  }

  /// Stops the reply in flight, keeping what has already arrived.
  Future<void> cancel() async {
    final buffered = state.value?.streamingText ?? '';
    _detachGeneration();
    await _finishGeneration(buffered);
  }

  /// Clears a reported failure so the composer is usable again.
  void dismissFailure() {
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(clearFailure: true));
    }
  }

  /// Drops the generation in flight.
  ///
  /// The cancel is **not** awaited, deliberately. Cancelling is effective the
  /// moment it is called — a stream's `onCancel` runs synchronously, and
  /// `LlmSession.send` is contracted to stop generating on it — but the future
  /// it returns resolves on the engine's own schedule. Awaiting it would leave
  /// the stop button doing visibly nothing for as long as the engine takes to
  /// acknowledge, which is exactly the frozen UI §8 calls a defect. Releasing
  /// the session's own resources is `LlmSession.dispose`'s job, and that *is*
  /// awaited, in `build`'s `onDispose`.
  void _detachGeneration() {
    final generation = _generation;
    _generation = null;
    if (generation != null) unawaited(generation.cancel());
  }

  /// Persists whatever was generated and returns the UI to rest.
  ///
  /// **The assistant reply is written once, here — never per token.** Every
  /// token is a transaction through SQLCipher, and a reply of a few hundred
  /// tokens would be a few hundred encrypted writes for one message that is only
  /// ever read back whole.
  Future<void> _finishGeneration(String reply, {Object? failure}) async {
    _generation = null;

    // Released first, and unconditionally: an early return below must not leave
    // the caller of `send` waiting on a turn that is already over.
    final turn = _turn;
    _turn = null;
    if (turn != null && !turn.isCompleted) turn.complete();

    final text = reply.trim();
    if (text.isNotEmpty) {
      await _repository.append(
        Message.fromAssistant(conversationId: conversationId, text: text),
      );
    }

    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        isTyping: false,
        streamingText: '',
        failure: failure,
        clearFailure: failure == null,
      ),
    );
  }

  /// Names the conversation after its opening message, once.
  ///
  /// See `ChatRepository.updateTitle`: derived, not a rename action.
  Future<void> _titleFrom(String firstMessage) async {
    final conversation = await _repository.findConversation(conversationId);
    if (conversation == null || conversation.title.isNotEmpty) return;

    const limit = 60;
    final oneLine = firstMessage.replaceAll(RegExp(r'\s+'), ' ').trim();
    // `characters`, not `length`: cutting a Dart string by code unit splits
    // surrogate pairs and combining marks, and Hebrew niqqud is exactly that.
    final graphemes = oneLine.characters;
    final title = graphemes.length <= limit
        ? oneLine
        : '${graphemes.take(limit).toString().trimRight()}…';

    await _repository.updateTitle(conversationId, title);
  }
}
