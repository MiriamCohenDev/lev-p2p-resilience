import 'dart:async';

import 'package:llamadart/llamadart.dart' as llama;

import '../../../llm/model_descriptor.dart';
import '../../../llm/model_file_store.dart';
import '../domain/llm_errors.dart';
import '../domain/llm_service.dart';
import '../domain/prompt.dart';
import '../domain/tokenizer.dart';
import 'calibrated_tokenizer.dart';

/// The real inference engine (technical-spec §9, Phase 3.1).
///
/// **This class is the whole of the Phase 3.1 swap.** It is registered in
/// `core/di/llm_providers.dart` in place of `FakeLlmService`.
///
/// §9's claim is that the swap leaves the chat untouched. Measured honestly:
/// `features/chat/presentation` did not change at all — not one widget, not the
/// notifier — and `features/chat/domain` changed only additively: `Prompt` gained
/// an optional [Prompt.assistantSuffix], and `llm_errors.dart` gained
/// [ModelIntegrityFailed]. No existing call site was edited, and every Phase 2
/// test still passes against the fake. That is what the phase order bought.
///
/// The one thing the fake could not have taught us is recorded here rather than
/// glossed over: a real session needs a running transcript, and therefore needs
/// to know how a reply is closed off. See [_LlamaCppSession].
///
/// It knows nothing about conversations, roles, templates or budgets. It
/// receives a rendered [Prompt] and streams text back. Everything model-specific
/// was decided one layer up, in `DefaultPromptBuilder` (#16).
class LlamaCppLlmService implements LlmService {
  LlamaCppLlmService({
    required this.fileStore,
    llama.LlamaEngine? engine,
    this.calibrationSamples = const [],
  }) : _engine = engine ?? llama.LlamaEngine(llama.LlamaBackend());

  final ModelFileStore fileStore;
  final llama.LlamaEngine _engine;

  /// Text used to measure this model's tokens-per-character at load time.
  ///
  /// See [CalibratedTokenizer]. Normally the system prompt plus a sample of the
  /// kind of prose the chat actually carries.
  final List<String> calibrationSamples;

  ModelDescriptor? _model;
  Tokenizer _tokenizer = const CalibratedTokenizer.uncalibrated();

  /// The session currently holding the context.
  ///
  /// llama.cpp gives one context per loaded model here, and the KV cache in it
  /// belongs to whichever conversation last prefilled. Two live sessions would
  /// silently overwrite each other's cache and answer each other's questions, so
  /// opening a second one closes the first rather than pretending both work.
  _LlamaCppSession? _session;

  @override
  Tokenizer get tokenizer => _tokenizer;

  ModelDescriptor? get loadedModel => _model;

  @override
  Future<void> loadModel(ModelDescriptor model) async {
    if (_model?.id == model.id) return;
    await unload();

    // Before anything is loaded: §7.5's integrity check, and the failure that
    // says the weights are simply not installed yet. Both are more useful before
    // llama.cpp has mapped several hundred megabytes than after.
    final path = await fileStore.pathFor(model);

    try {
      await _engine.loadModel(
        path,
        modelParams: llama.ModelParams(
          // The window the whole prompt layer budgets against. Passing the
          // descriptor's value rather than llama.cpp's default keeps
          // `promptBudgetTokens` honest: a context smaller than the manifest
          // claims would make every budget decision above this line wrong.
          contextSize: model.contextTokens,
        ),
      );
    } on llama.LlamaException catch (error) {
      throw ModelUnavailable(
        'llama.cpp could not load the weights for model "${model.id}" at '
        '$path: ${error.message}',
        cause: error,
      );
    }

    _model = model;
    _tokenizer = await CalibratedTokenizer.calibrate(
      countExact: _engine.getTokenCount,
      samples: calibrationSamples,
    );
  }

  @override
  Future<void> unload() async {
    await _session?.dispose();
    _session = null;
    if (_model == null) return;
    _model = null;
    _tokenizer = const CalibratedTokenizer.uncalibrated();
    await _engine.unloadModel();
  }

  @override
  Future<LlmSession> openSession({required Prompt seed}) async {
    final model = _model;
    if (model == null) {
      throw const ModelUnavailable(
        'openSession was called before loadModel; there are no weights to open '
        'a session against',
      );
    }

    await _session?.dispose();
    late final _LlamaCppSession session;
    session = _LlamaCppSession(
      engine: _engine,
      model: model,
      seed: seed,
      onDisposed: () {
        // Only if it is still the live one: a session disposed after a newer
        // one opened must not clear the newer one's registration.
        if (identical(_session, session)) _session = null;
      },
    );
    _session = session;

    // Deliberately *not* prefilled here, and this is the one place the real
    // engine departs from the fake's timing rather than its contract.
    // llama.cpp has no "ingest and stop" call — a prompt is ingested as the
    // opening act of a generation. Prefilling separately would mean generating
    // a token and throwing it away, which costs the user a full decode and
    // pollutes the KV cache with a token the conversation never contained.
    //
    // The seed is instead ingested by the first `send`, and `reusePromptPrefix`
    // makes every later turn pay only for its own tokens — which is the property
    // §5.1 actually asks for. The cost is that the first reply carries the
    // prefill latency; `isPrefilling` in the UI already covers exactly that.
    return session;
  }

  /// Frees the model and the native backend. Not part of [LlmService].
  Future<void> dispose() async {
    await unload();
    await _engine.dispose();
  }
}

/// One conversation's live context (technical-spec §5.1).
///
/// Holds the running transcript, because that is how llama.cpp's cache is
/// addressed: `generate` is given a whole prompt and reuses however much of the
/// KV cache still matches its prefix. Appending each turn and each reply to a
/// transcript and re-sending the whole thing therefore costs only the new
/// tokens, while sending just the new turn would throw the conversation away.
class _LlamaCppSession implements LlmSession {
  _LlamaCppSession({
    required this.engine,
    required this.model,
    required Prompt seed,
    required this.onDisposed,
  })  : _transcript = StringBuffer(seed.text),
        _assistantSuffix = seed.assistantSuffix;

  final llama.LlamaEngine engine;
  final ModelDescriptor model;
  final void Function() onDisposed;

  /// Everything the model has been shown in this conversation, rendered.
  final StringBuffer _transcript;

  /// How an assistant turn is closed for this model family, carried on the seed.
  final String _assistantSuffix;

  bool _disposed = false;

  @override
  Stream<String> send(Prompt turn) {
    if (_disposed) {
      return Stream<String>.error(
        const SessionClosed('send was called on a disposed session'),
      );
    }

    _transcript.write(turn.text);
    final prompt = _transcript.toString();
    final reply = StringBuffer();

    var cancelled = false;
    late final StreamController<String> controller;
    StreamSubscription<String>? subscription;

    // Cancellation must reach the engine, not merely stop delivery (§8, and the
    // contract on `LlmSession.send`). `cancelGeneration` is what stops the
    // decode loop inside llama.cpp; dropping the subscription alone would leave
    // the model generating a reply nobody will ever read, holding the context
    // busy and draining the battery.
    Future<void> stop() async {
      cancelled = true;
      engine.cancelGeneration();
      await subscription?.cancel();
      subscription = null;
    }

    /// Closes the assistant's turn in the transcript.
    ///
    /// Runs on every ending — completion, failure, and cancellation alike —
    /// because in all three the user has seen whatever arrived and the model
    /// must be told the same story next turn. Omitting it after a cancelled or
    /// failed reply would leave the transcript mid-assistant-turn, and the next
    /// prompt would ask the model to continue an answer the conversation has
    /// already moved past.
    void closeTurn() {
      _transcript
        ..write(reply.toString())
        ..write(_assistantSuffix);
    }

    controller = StreamController<String>(
      onCancel: () async {
        if (cancelled) return;
        closeTurn();
        await stop();
      },
      onListen: () {
        subscription = engine
            .generate(
              prompt,
              params: llama.GenerationParams(
                maxTokens: model.replyTokenReserve,
                stopSequences: turn.stopTokens,
                // The KV cache this session exists for. Without it llamadart
                // clears the context on every call and re-ingests the entire
                // conversation, so per-turn latency would climb with the length
                // of the conversation — the exact cost §5.1 introduces sessions
                // to avoid.
                reusePromptPrefix: true,
              ),
            )
            .listen(
          (token) {
            if (cancelled) return;
            reply.write(token);
            controller.add(token);
          },
          onError: (Object error, StackTrace stackTrace) {
            if (cancelled) return;
            closeTurn();
            controller.addError(
              GenerationFailed(
                'llama.cpp stopped generating part-way through: $error',
                cause: error,
              ),
              stackTrace,
            );
            controller.close();
          },
          onDone: () {
            if (cancelled) return;
            closeTurn();
            controller.close();
          },
        );
      },
    );

    return controller.stream;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    // The context is shared, so a disposed session must not leave a generation
    // running into it — the next session would inherit a busy engine.
    engine.cancelGeneration();
    onDisposed();
  }
}
