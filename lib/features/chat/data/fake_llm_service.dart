import 'dart:async';

import '../../../llm/model_descriptor.dart';
import '../domain/llm_errors.dart';
import '../domain/llm_service.dart';
import '../domain/prompt.dart';
import '../domain/tokenizer.dart';
import 'calibrated_tokenizer.dart';

/// How the fake engine should misbehave.
///
/// These are not test fixtures — they are the failure modes the chat UI has to
/// handle, made reachable without a model. §9's Phase 2.1 asks for exactly
/// this: an engine that "can be told to fail, stall, or simulate a slow prefill
/// on demand", so that Phase 2.2's error and loading states are built against
/// something real rather than imagined.
enum FakeEngineMode {
  /// Streams a canned reply, token by token.
  normal,

  /// Fails before the first token. Nothing reaches the screen.
  failBeforeFirstToken,

  /// Fails part-way through. Tokens already delivered stand — this is the case
  /// that catches a UI which discards a partial reply on error.
  failMidGeneration,

  /// Emits nothing and never completes, until the subscription is cancelled.
  /// A UI that shows a spinner with no way out will hang here, which is the
  /// point.
  stall,
}

/// An [LlmService] with no model and no native code (technical-spec §9, 2.1).
///
/// The chat is built and finished against this. §9's rationale: the native
/// binding is the riskiest, most environment-dependent part of the build, so
/// writing the chat against a fake first unblocks all chat work from toolchain
/// problems and forces this interface to stay clean — which is what makes the
/// Phase 3.1 swap a change to one DI binding.
///
/// Nothing here may leak into the contracts. If the chat ever needs something
/// only this class can provide, the interface is wrong.
class FakeLlmService implements LlmService {
  FakeLlmService({
    this.tokenizer = const CalibratedTokenizer.uncalibrated(),
    this.tokenDelay = const Duration(milliseconds: 20),
    this.prefillDelay = Duration.zero,
    this.mode = FakeEngineMode.normal,
    List<String>? replies,
  }) : _replies = replies ?? _cannedReplies;

  @override
  final Tokenizer tokenizer;

  /// Per-token pacing, so the UI is exercised as a stream rather than as a
  /// single frame containing the whole answer.
  final Duration tokenDelay;

  /// Stands in for the prefill cost §5.1 makes the UI surface as `isPrefilling`.
  Duration prefillDelay;

  FakeEngineMode mode;

  final List<String> _replies;

  ModelDescriptor? _model;

  /// Every prompt this engine was given, in order.
  ///
  /// The seam the prompt-layer tests use: §9's 2.3 done-criterion is about what
  /// gets *rendered*, and this is where a test reads it back.
  final List<Prompt> received = [];

  /// Total tokens emitted across all sessions. A cancellation test asserts this
  /// stops rising.
  int tokensEmitted = 0;

  int _replyCursor = 0;

  ModelDescriptor? get loadedModel => _model;

  @override
  Future<void> loadModel(ModelDescriptor model) async {
    _model = model;
  }

  @override
  Future<void> unload() async {
    _model = null;
  }

  @override
  Future<LlmSession> openSession({required Prompt seed}) async {
    if (_model == null) {
      throw const ModelUnavailable(
        'openSession was called before loadModel; the fake engine still models '
        'the real one, where a session cannot exist without weights',
      );
    }

    received.add(seed);
    if (prefillDelay > Duration.zero) {
      await Future<void>.delayed(prefillDelay);
    }

    return _FakeLlmSession(this);
  }

  /// The next canned reply, cycling so a multi-turn conversation does not read
  /// as the same sentence three times.
  String _nextReply() {
    final reply = _replies[_replyCursor % _replies.length];
    _replyCursor++;
    return reply;
  }

  /// Deliberately in the product's voice (§5.2.1) rather than lorem ipsum: the
  /// bubbles, wrapping and RTL layout are being judged by eye during Phase 2.2,
  /// and placeholder text hides how the real thing will look.
  static const List<String> _cannedReplies = [
    'That sounds like a lot to be carrying. Tell me what feels heaviest right '
        'now, and we can look at it one piece at a time.',
    'It makes sense that you would feel that way. Nothing you have described '
        'sounds unreasonable to me.',
    'Let us slow down for a moment. Of everything you have said, which part '
        'would you most want to be different tomorrow?',
    'You have already worked out more of this than you are giving yourself '
        'credit for. What would the next small step look like?',
  ];
}

class _FakeLlmSession implements LlmSession {
  _FakeLlmSession(this._service);

  final FakeLlmService _service;
  bool _disposed = false;

  @override
  Stream<String> send(Prompt turn) {
    if (_disposed) {
      return Stream<String>.error(
        const SessionClosed('send was called on a disposed session'),
      );
    }

    _service.received.add(turn);

    // Cancellation has to reach the producing loop, not merely stop delivery:
    // an engine that keeps generating into a dropped stream holds the model
    // busy and burns the battery §8 asks us to watch. `cancelled` is the flag
    // the loop below checks; `onCancel` is the only thing that sets it.
    var cancelled = false;
    late final StreamController<String> controller;

    Future<void> emit(String token) async {
      await Future<void>.delayed(_service.tokenDelay);
      if (cancelled) return;
      _service.tokensEmitted++;
      controller.add(token);
    }

    controller = StreamController<String>(
      onCancel: () => cancelled = true,
      onListen: () async {
        // Ahead of the try, and deliberately: a stall must leave the stream
        // *open*. Returning from inside the block below would run its `finally`
        // and close the controller, which delivers a done event — the one thing
        // a stalled engine does not do. A UI tested against that would look
        // correct here and hang in front of a user.
        if (_service.mode == FakeEngineMode.stall) return;

        try {
          switch (_service.mode) {
            case FakeEngineMode.stall:
              return;

            case FakeEngineMode.failBeforeFirstToken:
              await Future<void>.delayed(_service.tokenDelay);
              if (cancelled) return;
              controller.addError(
                const GenerationFailed('the fake engine was told to fail'),
              );

            case FakeEngineMode.normal:
            case FakeEngineMode.failMidGeneration:
              final tokens = _tokenize(_service._nextReply());
              final failAt = _service.mode == FakeEngineMode.failMidGeneration
                  ? tokens.length ~/ 3
                  : -1;

              for (var i = 0; i < tokens.length; i++) {
                if (cancelled) return;
                if (i == failAt && failAt > 0) {
                  controller.addError(
                    const GenerationFailed(
                      'the fake engine was told to fail part-way through',
                    ),
                  );
                  return;
                }
                await emit(tokens[i]);
              }
          }
        } finally {
          if (!cancelled && !controller.isClosed) await controller.close();
        }
      },
    );

    return controller.stream;
  }

  /// Splits a reply into the chunks a real engine would emit.
  ///
  /// Whitespace-preserving: the UI concatenates what it receives, so a splitter
  /// that dropped the spaces would look correct here and wrong on screen.
  List<String> _tokenize(String reply) {
    final matches = RegExp(r'\S+\s*').allMatches(reply);
    return [for (final match in matches) match[0]!];
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
  }
}
