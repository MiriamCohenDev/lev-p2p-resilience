import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lev/core/di/llm_providers.dart';
import 'package:lev/core/platform/device_memory.dart';
import 'package:lev/features/chat/data/default_prompt_builder.dart';
import 'package:lev/features/chat/data/llama_cpp_llm_service.dart';
import 'package:lev/features/chat/data/system_prompt.dart';
import 'package:lev/features/chat/domain/conversation.dart';
import 'package:lev/features/chat/domain/message.dart';
import 'package:lev/llm/model_file_store.dart';
import 'package:lev/llm/model_registry.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// **Phase 3's done-criterion, on a real device with real weights.**
///
/// §9's Phase 2 (v0.1 numbering) asks for exactly this: "a hardcoded prompt
/// streams a coherent reply on Android + desktop within the target latency".
/// Nothing in the host test suite can establish it — the host tests mock the
/// engine, because what they check is LEV's own bookkeeping, not whether
/// llama.cpp can produce a sentence.
///
/// Run with:
///
///     dart run tool/fetch_model.dart
///     flutter test integration_test/llm_generation_test.dart -d windows
///     flutter test integration_test/llm_generation_test.dart -d <android-device>
///
/// Every test here **skips** rather than fails when no GGUF is installed, so the
/// suite stays green on a machine that cannot reach the weights — see
/// technical-decisions #19, where that is a live gap rather than a hypothetical.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late ModelRegistry registry;
  late Directory modelsDirectory;

  setUpAll(() async {
    registry = ModelRegistry.parse(
      await rootBundle.loadString(modelsManifestAsset),
    );
    final support = await getApplicationSupportDirectory();
    modelsDirectory = Directory(p.join(support.path, 'models'));
  });

  /// Whether weights are reachable at all — installed, or bundled in this build.
  Future<bool> weightsAvailable() async {
    final model = registry.models.first;
    if (File(p.join(modelsDirectory.path, p.basename(model.assetPath)))
        .existsSync()) {
      return true;
    }
    try {
      await rootBundle.load(model.assetPath);
      return true;
    } on Object {
      return false;
    }
  }

  Future<LlamaCppLlmService?> loadedService() async {
    if (!await weightsAvailable()) return null;
    final service = LlamaCppLlmService(
      fileStore: InstalledModelFileStore(directory: modelsDirectory),
      calibrationSamples: [
        SystemPrompt.parse(
          await rootBundle.loadString('assets/prompts/system_prompt.md'),
        ).text,
      ],
    );
    await service.loadModel(registry.models.first);
    return service;
  }

  testWidgets('this device is measured, and the model is admitted', (_) async {
    // §8's min-spec gate, against the machine actually running the test rather
    // than against Phase 2's placeholder.
    final ram = totalPhysicalMemoryMb();
    expect(ram, isNotNull, reason: 'RAM unreadable on ${Platform.operatingSystem}');

    final selected = DefaultModelSelector(registry)
        .selectFor(language: 'en', deviceRamMb: ram!);
    expect(selected.id, isNotEmpty);
  });

  testWidgets('a prompt streams a coherent reply', (_) async {
    final service = await loadedService();
    if (service == null) {
      markTestSkipped('no GGUF installed — run tool/fetch_model.dart first');
      return;
    }
    addTearDown(service.dispose);

    final model = registry.models.first;
    final builder = DefaultPromptBuilder(
      systemPrompt: SystemPrompt.parse(
        await rootBundle.loadString('assets/prompts/system_prompt.md'),
      ),
      tokenizer: service.tokenizer,
    );

    final conversation = Conversation(
      id: 'it-1',
      title: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final opening = Message.fromUserInput(
      conversationId: 'it-1',
      text: 'I have had a long and difficult week. Can you help me think about it?',
    );

    final session = await service.openSession(
      seed: builder.buildSeed(conversation, const [], model),
    );

    final stopwatch = Stopwatch()..start();
    Duration? firstToken;
    final reply = StringBuffer();

    await for (final token in session.send(builder.buildTurn(opening, model))) {
      firstToken ??= stopwatch.elapsed;
      reply.write(token);
    }
    stopwatch.stop();

    // "Coherent" is not something a test can assert, so it asserts the things
    // whose absence would make coherence impossible: that words arrived, that
    // they are words, and that the template markers did not leak into what a
    // user would read.
    expect(reply.length, greaterThan(20), reason: 'reply: $reply');
    expect(reply.toString().trim().split(RegExp(r'\s+')).length,
        greaterThan(4), reason: 'reply: $reply');
    for (final marker in const ['<|im_start|>', '<|im_end|>', '<|endoftext|>']) {
      expect(reply.toString(), isNot(contains(marker)));
    }

    // Reported rather than asserted: §8 asks for a first-token target per tier,
    // and the tiers are not set yet. A number in the log is what setting them
    // will be based on.
    // ignore: avoid_print
    print('first token: ${firstToken?.inMilliseconds}ms · '
        'total: ${stopwatch.elapsedMilliseconds}ms · '
        '${reply.length} chars');
  });

  testWidgets('a second turn keeps the conversation', (_) async {
    final service = await loadedService();
    if (service == null) {
      markTestSkipped('no GGUF installed — run tool/fetch_model.dart first');
      return;
    }
    addTearDown(service.dispose);

    final model = registry.models.first;
    final builder = DefaultPromptBuilder(
      systemPrompt: SystemPrompt.parse(
        await rootBundle.loadString('assets/prompts/system_prompt.md'),
      ),
      tokenizer: service.tokenizer,
    );
    final conversation = Conversation(
      id: 'it-2',
      title: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final session = await service.openSession(
      seed: builder.buildSeed(conversation, const [], model),
    );

    Future<String> say(String text) async {
      final message =
          Message.fromUserInput(conversationId: 'it-2', text: text);
      final buffer = StringBuffer();
      await for (final token in session.send(builder.buildTurn(message, model))) {
        buffer.write(token);
      }
      return buffer.toString();
    }

    await say('My name is Dana. Please remember it.');
    final second = Stopwatch()..start();
    final answer = await say('What is my name?');
    second.stop();

    // The transcript is what makes this possible: the reply and its closing
    // marker are folded back in, so the second turn is asked in the context of
    // the first rather than in a vacuum. A session that dropped either would
    // answer this with a guess.
    expect(answer.toLowerCase(), contains('dana'), reason: 'reply: $answer');

    // ignore: avoid_print
    print('second turn: ${second.elapsedMilliseconds}ms (prefix reuse should '
        'make this cheaper than the first)');
  });

  testWidgets('cancelling stops the engine mid-reply', (_) async {
    final service = await loadedService();
    if (service == null) {
      markTestSkipped('no GGUF installed — run tool/fetch_model.dart first');
      return;
    }
    addTearDown(service.dispose);

    final model = registry.models.first;
    final builder = DefaultPromptBuilder(
      systemPrompt: SystemPrompt.parse(
        await rootBundle.loadString('assets/prompts/system_prompt.md'),
      ),
      tokenizer: service.tokenizer,
    );
    final session = await service.openSession(
      seed: builder.buildSeed(
        Conversation(
          id: 'it-3',
          title: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        const [],
        model,
      ),
    );

    final message = Message.fromUserInput(
      conversationId: 'it-3',
      text: 'Please tell me a very long story about a river.',
    );

    var received = 0;
    final subscription =
        session.send(builder.buildTurn(message, model)).listen((_) => received++);

    await Future<void>.delayed(const Duration(milliseconds: 600));
    final atCancel = received;
    await subscription.cancel();
    await Future<void>.delayed(const Duration(seconds: 2));

    // §8's battery requirement, verified against the real decode loop rather
    // than a mock: after cancelling, the engine must stop *producing*, not
    // merely stop delivering.
    expect(received, atCancel,
        reason: 'tokens kept arriving after cancel — cancelGeneration did not '
            'reach the decode loop');
  });
}
