import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lev/features/chat/data/fake_llm_service.dart';
import 'package:lev/features/chat/domain/llm_errors.dart';
import 'package:lev/features/chat/domain/prompt.dart';
import 'package:lev/llm/model_descriptor.dart';

/// The fake engine is the only engine Phase 2 has, so the guarantees the chat
/// is written against are the ones asserted here — above all that cancelling a
/// subscription actually stops generation (technical-spec §5.1, §9 2.1).
void main() {
  const model = ModelDescriptor(
    id: 'test-model',
    family: 'qwen',
    assetPath: 'assets/models/none.gguf',
    sha256: '',
    language: 'en',
    minRamMb: 0,
    contextTokens: 4096,
    replyTokenReserve: 512,
    stopTokens: ['<|im_end|>'],
    quantization: 'Q4_K_M',
  );

  const seed = Prompt(text: 'seed', stopTokens: [], estimatedTokens: 1);
  const turn = Prompt(text: 'turn', stopTokens: [], estimatedTokens: 1);

  Future<FakeLlmService> loaded({
    FakeEngineMode mode = FakeEngineMode.normal,
    Duration tokenDelay = Duration.zero,
    Duration prefillDelay = Duration.zero,
    List<String>? replies,
  }) async {
    final service = FakeLlmService(
      mode: mode,
      tokenDelay: tokenDelay,
      prefillDelay: prefillDelay,
      replies: replies,
    );
    await service.loadModel(model);
    return service;
  }

  group('loading', () {
    test('a session cannot be opened before a model is loaded', () async {
      final service = FakeLlmService();

      await expectLater(
        service.openSession(seed: seed),
        throwsA(isA<ModelUnavailable>()),
      );
    });

    test('unload releases the model', () async {
      final service = await loaded();

      await service.unload();

      expect(service.loadedModel, isNull);
      await expectLater(
        service.openSession(seed: seed),
        throwsA(isA<ModelUnavailable>()),
      );
    });
  });

  group('streaming', () {
    test('delivers the canned reply in order and in full', () async {
      final service = await loaded(replies: ['one two three']);
      final session = await service.openSession(seed: seed);

      final chunks = await session.send(turn).toList();

      // Concatenation, not join: the chunks carry their own trailing spaces, so
      // a UI that simply appends them reproduces the reply exactly.
      expect(chunks.join(), 'one two three');
      expect(chunks.length, greaterThan(1), reason: 'must arrive as a stream');
    });

    test('cycles replies so a multi-turn conversation varies', () async {
      final service = await loaded(replies: ['first', 'second']);
      final session = await service.openSession(seed: seed);

      expect((await session.send(turn).toList()).join(), 'first');
      expect((await session.send(turn).toList()).join(), 'second');
      expect((await session.send(turn).toList()).join(), 'first');
    });

    test('records every prompt it was given', () async {
      final service = await loaded(replies: ['ok']);
      final session = await service.openSession(seed: seed);

      await session.send(turn).drain<void>();

      expect(service.received.map((p) => p.text), ['seed', 'turn']);
    });
  });

  group('cancellation', () {
    test('stops generation, not merely delivery', () async {
      final service = await loaded(
        tokenDelay: const Duration(milliseconds: 5),
        replies: [List.filled(200, 'word').join(' ')],
      );
      final session = await service.openSession(seed: seed);

      final subscription = session.send(turn).listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await subscription.cancel();

      final atCancel = service.tokensEmitted;
      expect(atCancel, greaterThan(0), reason: 'it should have started');
      expect(atCancel, lessThan(200), reason: 'it should not have finished');

      // The real assertion: nothing kept running behind the cancelled stream.
      // A fire-and-forget producer would keep incrementing right through this.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(service.tokensEmitted, atCancel);
    });

    test('a cancelled stall stops waiting', () async {
      final service = await loaded(mode: FakeEngineMode.stall);
      final session = await service.openSession(seed: seed);

      final received = <String>[];
      final subscription = session.send(turn).listen(received.add);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(received, isEmpty);
      await subscription.cancel();
    });
  });

  group('failure modes', () {
    test('failBeforeFirstToken surfaces a typed error with no tokens',
        () async {
      final service = await loaded(mode: FakeEngineMode.failBeforeFirstToken);
      final session = await service.openSession(seed: seed);

      await expectLater(
        session.send(turn),
        emitsInOrder([emitsError(isA<GenerationFailed>()), emitsDone]),
      );
    });

    test('failMidGeneration keeps the tokens already delivered', () async {
      final service = await loaded(
        mode: FakeEngineMode.failMidGeneration,
        replies: [List.filled(30, 'word').join(' ')],
      );
      final session = await service.openSession(seed: seed);

      final delivered = <String>[];
      Object? error;
      // `handleError` rather than `listen(onError:)` plus `asFuture`: asFuture
      // replaces the subscription's error handler with its own, so the two
      // together silently swallow the error this test is about.
      await session
          .send(turn)
          .handleError((Object e) => error = e)
          .forEach(delivered.add);

      expect(error, isA<GenerationFailed>());
      expect(delivered, isNotEmpty,
          reason: 'a partial reply is real and must not be discarded');
      expect(delivered.length, lessThan(30));
    });

    test('stall emits nothing within a generous window', () async {
      final service = await loaded(mode: FakeEngineMode.stall);
      final session = await service.openSession(seed: seed);

      await expectLater(
        session.send(turn).timeout(const Duration(milliseconds: 50)),
        emitsError(isA<TimeoutException>()),
      );
    });
  });

  group('prefill', () {
    test('openSession takes as long as it was told to', () async {
      final service = await loaded(
        prefillDelay: const Duration(milliseconds: 60),
      );

      final stopwatch = Stopwatch()..start();
      await service.openSession(seed: seed);
      stopwatch.stop();

      // The UI must show `isPrefilling` across this window (§5.1); a fake that
      // returned instantly would let a missing indicator pass unnoticed.
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(50));
    });
  });

  group('disposal', () {
    test('sending on a disposed session errors rather than generating',
        () async {
      final service = await loaded();
      final session = await service.openSession(seed: seed);

      await session.dispose();

      await expectLater(
        session.send(turn),
        emitsError(isA<SessionClosed>()),
      );
      expect(service.tokensEmitted, 0);
    });
  });
}
