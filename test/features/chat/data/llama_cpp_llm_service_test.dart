import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lev/features/chat/data/llama_cpp_llm_service.dart';
import 'package:lev/features/chat/domain/llm_errors.dart';
import 'package:lev/features/chat/domain/prompt.dart';
import 'package:lev/llm/model_descriptor.dart';
import 'package:lev/llm/model_file_store.dart';
import 'package:llamadart/llamadart.dart' as llama;
import 'package:mocktail/mocktail.dart';

/// The engine is mocked rather than run: these tests are about the session
/// bookkeeping LEV owns — the transcript, cancellation, disposal — not about
/// whether llama.cpp can produce a sentence. What llama.cpp does with a prompt
/// is verified on a device, with weights, in `integration_test/`.
class _MockEngine extends Mock implements llama.LlamaEngine {}

class _StubFileStore implements ModelFileStore {
  @override
  Future<String> pathFor(ModelDescriptor model) async =>
      '/nowhere/${model.id}.gguf';
}

const _model = ModelDescriptor(
  id: 'qwen-en-q4',
  family: 'qwen',
  assetPath: 'assets/models/qwen-en-q4.gguf',
  sha256: '',
  language: 'en',
  minRamMb: 1536,
  contextTokens: 4096,
  replyTokenReserve: 512,
  stopTokens: ['<|im_end|>'],
  quantization: 'Q4_K_M',
);

const _seed = Prompt(
  text: '<|im_start|>system\nYou are LEV.<|im_end|>\n<|im_start|>assistant\n',
  stopTokens: ['<|im_end|>'],
  estimatedTokens: 12,
  assistantSuffix: '<|im_end|>\n',
);

Prompt _turn(String text) => Prompt(
      text: '<|im_start|>user\n$text<|im_end|>\n<|im_start|>assistant\n',
      stopTokens: const ['<|im_end|>'],
      estimatedTokens: 8,
      assistantSuffix: '<|im_end|>\n',
    );

void main() {
  setUpAll(() {
    registerFallbackValue(const llama.GenerationParams());
    registerFallbackValue(const llama.ModelParams());
  });

  late _MockEngine engine;
  late LlamaCppLlmService service;
  late List<String> promptsSeen;
  late StreamController<String> generation;

  setUp(() async {
    engine = _MockEngine();
    promptsSeen = [];
    generation = StreamController<String>();

    when(() => engine.loadModel(any(), modelParams: any(named: 'modelParams')))
        .thenAnswer((_) async {});
    when(() => engine.unloadModel()).thenAnswer((_) async {});
    when(() => engine.dispose()).thenAnswer((_) async {});
    when(() => engine.cancelGeneration()).thenReturn(null);
    when(() => engine.getTokenCount(any())).thenAnswer((i) async {
      return ((i.positionalArguments.first as String).length / 3).ceil();
    });
    when(() => engine.generate(any(), params: any(named: 'params')))
        .thenAnswer((invocation) {
      promptsSeen.add(invocation.positionalArguments.first as String);
      return generation.stream;
    });

    service = LlamaCppLlmService(fileStore: _StubFileStore(), engine: engine);
    await service.loadModel(_model);
  });

  test('the descriptor\'s context window is what llama.cpp is given', () async {
    // Anything else makes `promptBudgetTokens` a lie: the prompt layer budgets
    // against the manifest, so a context of a different size means every fitting
    // decision above this line was made against the wrong number.
    final params = verify(
      () => engine.loadModel(any(), modelParams: captureAny(named: 'modelParams')),
    ).captured.single as llama.ModelParams;
    expect(params.contextSize, _model.contextTokens);
  });

  test('a session cannot be opened before weights are loaded', () async {
    final empty = LlamaCppLlmService(fileStore: _StubFileStore(), engine: engine);
    await expectLater(
      empty.openSession(seed: _seed),
      throwsA(isA<ModelUnavailable>()),
    );
  });

  group('the transcript', () {
    test('the first turn is prefixed by the seed', () async {
      final session = await service.openSession(seed: _seed);
      final tokens = session.send(_turn('hello')).toList();

      generation
        ..add('Hi.')
        ..close();
      await tokens;

      // The seed is ingested here rather than in openSession: llama.cpp has no
      // "ingest and stop" call, so prefilling separately would mean decoding a
      // token and discarding it.
      expect(promptsSeen.single, startsWith(_seed.text));
      expect(promptsSeen.single, endsWith(_turn('hello').text));
    });

    test('the reply is folded back in, closed by the assistant suffix',
        () async {
      final session = await service.openSession(seed: _seed);

      var first = session.send(_turn('hello')).toList();
      generation
        ..add('Hi ')
        ..add('there.')
        ..close();
      await first;

      generation = StreamController<String>();
      final second = session.send(_turn('again')).toList();
      generation.close();
      await second;

      // Without the suffix the transcript stays mid-assistant-turn and the model
      // answers as the user from here on. Without the reply, the model is asked
      // a follow-up to something it never said.
      expect(
        promptsSeen.last,
        contains('Hi there.<|im_end|>\n<|im_start|>user\nagain'),
      );
    });

    test('a cancelled reply is still closed off', () async {
      final session = await service.openSession(seed: _seed);
      final subscription = session.send(_turn('hello')).listen(null);
      generation.add('Half a th');
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      generation = StreamController<String>();
      final next = session.send(_turn('never mind')).toList();
      generation.close();
      await next;

      // The user saw a partial reply and moved on. The model has to be told the
      // same story, or the next prompt asks it to continue an answer the
      // conversation has already left behind.
      expect(promptsSeen.last, contains('Half a th<|im_end|>\n'));
    });
  });

  group('cancellation', () {
    test('reaches the engine, not just the stream', () async {
      final session = await service.openSession(seed: _seed);
      final subscription = session.send(_turn('hello')).listen(null);
      await Future<void>.delayed(Duration.zero);

      await subscription.cancel();

      // §8's battery requirement, and the contract on `LlmSession.send`. An
      // engine left generating into a dropped stream holds the context busy and
      // burns power producing a reply nobody will read.
      verify(() => engine.cancelGeneration()).called(greaterThanOrEqualTo(1));
    });

    test('tokens already delivered stand when generation fails', () async {
      final session = await service.openSession(seed: _seed);
      final received = <String>[];
      final done = Completer<Object>();

      session.send(_turn('hello')).listen(
            received.add,
            onError: done.complete,
            cancelOnError: true,
          );

      generation
        ..add('Partly ')
        ..add('said')
        ..addError(StateError('the context ran out'));

      final error = await done.future;
      expect(error, isA<GenerationFailed>());
      expect(received.join(), 'Partly said');
    });
  });

  test('opening a second session closes the first', () async {
    // One llama.cpp context means one KV cache. Two live sessions would
    // overwrite each other's and answer each other's questions, so the older one
    // is closed rather than left looking usable.
    final first = await service.openSession(seed: _seed);
    await service.openSession(seed: _seed);

    await expectLater(
      first.send(_turn('hello')),
      emitsError(isA<SessionClosed>()),
    );
  });

  test('unloading leaves the tokenizer safe to use', () async {
    // The prompt layer holds a `Tokenizer` and does not re-resolve it on every
    // call. One that threw after unload would take the chat down on the way out.
    await service.unload();
    expect(service.tokenizer.count('some text'), greaterThan(0));
  });
}
