import 'dart:async';

import 'package:characters/characters.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/chat_providers.dart';
import '../../../core/di/llm_providers.dart';
import '../../../core/di/prompt_providers.dart';
import '../../../llm/model_descriptor.dart';
import '../data/conversation_summariser.dart';
import '../domain/chat_repository.dart';
import '../domain/llm_service.dart';
import '../domain/message.dart';
import '../domain/prompt_builder.dart';
import '../domain/safety_checker.dart';
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
  late final SafetyChecker _safetyChecker;
  late final ConversationSummariser _summariser;
  late final LlmService _llm;
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

    _llm = await ref.watch(llmServiceProvider.future);
    _model = await ref.watch(activeModelProvider.future);
    _promptBuilder = await ref.watch(promptBuilderProvider.future);
    _safetyChecker = await ref.watch(safetyCheckerProvider.future);
    _summariser = ref.watch(conversationSummariserProvider);

    // The one prefill §5.1 describes. The screen shows `AsyncLoading` across
    // it; `isPrefilling` covers a re-prefill on an already-built state.
    final seed = _promptBuilder.buildSeed(conversation, history, _model);
    final session = await _llm.openSession(seed: seed);
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

    // Before the model sees it, and independent of what the model does with it
    // (§5.2.4). The notice is shown alongside the reply, never instead of it —
    // replacing the answer would tell someone in distress that saying the wrong
    // thing gets them shut out of the conversation.
    final verdict = _safetyChecker.evaluate(trimmed);

    state = AsyncData(
      current.copyWith(
        isTyping: true,
        streamingText: '',
        clearFailure: true,
        safetyNotice: verdict.supportMessage,
        clearSafetyNotice: !verdict.matched,
      ),
    );

    final userMessage = Message.fromUserInput(
      conversationId: conversationId,
      text: trimmed,
    );
    await _repository.append(userMessage);
    await _titleFrom(trimmed);

    await _runTurn(session, userMessage);
  }

  /// Asks again for the reply to the last thing the user said.
  ///
  /// What the "try again" on a cut-off reply does. The user's message is **not**
  /// appended a second time — it is already stored and already on screen, and a
  /// duplicate would rewrite the conversation to say something the user never
  /// said twice. Only the generation is repeated.
  ///
  /// The safety layer is not re-run either: it evaluated this message when it
  /// was sent, and its notice, if there was one, is still on screen. Running it
  /// again would either show the card twice or, worse, look like it had changed
  /// its mind.
  Future<void> retryLastTurn() async {
    final current = state.value;
    final session = _session;
    if (current == null || session == null || current.isBusy) return;

    Message? lastUserMessage;
    for (final message in current.messages.reversed) {
      if (message.isFromUser) {
        lastUserMessage = message;
        break;
      }
    }
    if (lastUserMessage == null) return;

    state = AsyncData(
      current.copyWith(isTyping: true, streamingText: '', clearFailure: true),
    );

    await _runTurn(session, lastUserMessage);
  }

  /// Streams one reply for [userMessage]. The half [send] and [retryLastTurn]
  /// share, so a retry cannot drift out of step with a first attempt.
  Future<void> _runTurn(LlmSession session, Message userMessage) async {
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

    await _foldOverflowIntoSummary();
  }

  /// Folds turns that no longer fit into the rolling summary (§5.2.3).
  ///
  /// Runs after the turn is on screen, not before the next one is sent: this
  /// asks the model for a second generation, and doing it in front of the user
  /// would stall the conversation for the one thing they cannot see the point
  /// of. A failure here is swallowed — the same turns are simply offered again
  /// next time, which is a wasted call, not a broken conversation.
  Future<void> _foldOverflowIntoSummary() async {
    final conversation = await _repository.findConversation(conversationId);
    if (conversation == null) return;

    final history = await _repository.messagesOf(conversationId);
    final folded = _promptBuilder.overflow(conversation, history, _model);
    if (folded.isEmpty) return;

    final summary = await _summariser.summarise(
      llm: _llm,
      model: _model,
      folded: folded,
      previousSummary: conversation.summary,
    );
    if (summary == null || summary.isEmpty) return;

    await _repository.saveSummary(conversationId, summary, folded.last.id);
  }

  /// Names the conversation after its opening message, once.
  ///
  /// See `ChatRepository.updateTitle`. The guard below is what keeps this out
  /// of the way of a title a person chose from the row's menu.
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
