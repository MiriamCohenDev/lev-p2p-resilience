import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lev/features/chat/data/calibrated_tokenizer.dart';
import 'package:lev/features/chat/data/default_prompt_builder.dart';
import 'package:lev/features/chat/data/system_prompt.dart';
import 'package:lev/features/chat/domain/conversation.dart';
import 'package:lev/features/chat/domain/message.dart';
import 'package:lev/llm/model_registry.dart';

/// **Phase 3.3's done-criterion, as a test.**
///
/// §5.3 claims that adding a model — a Hebrew one, a larger desktop one — is a
/// manifest entry plus a GGUF file, with no change under `features/chat`. That
/// claim is easy to state and easy to quietly break: one `if (model.id == …)`
/// anywhere in the chain turns it into a lie, and nothing else would notice.
///
/// So this drives the whole chain from a manifest **string** — registry,
/// selector, prompt builder — and changes nothing but that string between cases.
/// Every assertion below would fail if any per-model behaviour had leaked into
/// Dart.
void main() {
  final systemPrompt = SystemPrompt.parse(
    '---\nversion: 1\n---\nYou are LEV, a calm and supportive companion.',
  );
  final builder = DefaultPromptBuilder(
    systemPrompt: systemPrompt,
    tokenizer: const CalibratedTokenizer.uncalibrated(),
  );

  final conversation = Conversation(
    id: 'c1',
    title: 'test',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
  final history = [
    Message.fromUserInput(conversationId: 'c1', text: 'hello'),
  ];

  Map<String, Object?> entry({
    required String id,
    required String family,
    required String language,
    int minRamMb = 1536,
    int contextTokens = 4096,
    List<String> stopTokens = const ['<|im_end|>'],
  }) =>
      {
        'id': id,
        'family': family,
        'assetPath': 'assets/models/$id.gguf',
        'sha256': '',
        'language': language,
        'minRamMb': minRamMb,
        'contextTokens': contextTokens,
        'replyTokenReserve': 512,
        'stopTokens': stopTokens,
        'quantization': 'Q4_K_M',
      };

  String manifest(List<Map<String, Object?>> models) =>
      jsonEncode({'models': models});

  const english = 'qwen-en-q4';

  test('a manifest entry is all it takes to add a Hebrew model', () {
    // Before: the Hebrew-reading user gets the English model, because that is
    // the only one there (§10's open Hebrew gap, and why the selector falls back
    // rather than returning nothing).
    final before = DefaultModelSelector(
      ModelRegistry.parse(manifest([
        entry(id: english, family: 'qwen', language: 'en'),
      ])),
    );
    expect(before.selectFor(language: 'he', deviceRamMb: 4096).id, english);

    // After: one more entry in the same JSON. No Dart changed between these two
    // statements — that is the entire claim.
    final after = DefaultModelSelector(
      ModelRegistry.parse(manifest([
        entry(id: english, family: 'qwen', language: 'en'),
        entry(id: 'dicta-he-q4', family: 'llama', language: 'he'),
      ])),
    );
    expect(after.selectFor(language: 'he', deviceRamMb: 4096).id, 'dicta-he-q4');
    // And the English user is undisturbed by the addition.
    expect(after.selectFor(language: 'en', deviceRamMb: 4096).id, english);
  });

  test('the new model brings its own template and stop tokens with it', () {
    final registry = ModelRegistry.parse(manifest([
      entry(id: english, family: 'qwen', language: 'en'),
      entry(
        id: 'dicta-he-q4',
        family: 'llama',
        language: 'he',
        stopTokens: const ['<|eot_id|>'],
      ),
    ]));
    final selector = DefaultModelSelector(registry);

    final qwen = builder.buildSeed(
      conversation,
      history,
      selector.selectFor(language: 'en', deviceRamMb: 4096),
    );
    final llama = builder.buildSeed(
      conversation,
      history,
      selector.selectFor(language: 'he', deviceRamMb: 4096),
    );

    // The rendered prompt follows the family named in the manifest.
    expect(qwen.text, contains('<|im_start|>system'));
    expect(llama.text, contains('<|begin_of_text|>'));
    expect(llama.text, contains('<|start_header_id|>system<|end_header_id|>'));

    // So does the marker the engine's session uses to close a reply. Phase 3
    // added this one, and it is exactly the kind of per-family detail that would
    // otherwise have ended up hardcoded in the engine.
    expect(qwen.assistantSuffix, '<|im_end|>\n');
    expect(llama.assistantSuffix, '<|eot_id|>');

    // And the stop tokens are the manifest's, not a constant.
    expect(qwen.stopTokens, const ['<|im_end|>']);
    expect(llama.stopTokens, const ['<|eot_id|>']);
  });

  test('a desktop-tier model is admitted only where it fits', () {
    // §8's min-spec gate, driven entirely from the manifest: the same registry
    // answers differently on a phone and on a laptop, with no device-specific
    // code anywhere.
    final selector = DefaultModelSelector(
      ModelRegistry.parse(manifest([
        entry(id: english, family: 'qwen', language: 'en'),
        entry(
          id: 'qwen-en-q8-desktop',
          family: 'qwen',
          language: 'en',
          minRamMb: 16384,
          contextTokens: 32768,
        ),
      ])),
    );

    expect(selector.selectFor(language: 'en', deviceRamMb: 3072).id, english);
    expect(
      selector.selectFor(language: 'en', deviceRamMb: 32768).id,
      'qwen-en-q8-desktop',
    );
  });

  test('the larger window is what the prompt layer then budgets against', () {
    // The gate is not cosmetic: selecting the desktop model has to actually give
    // the conversation more room, or the tiers are decoration.
    final selector = DefaultModelSelector(
      ModelRegistry.parse(manifest([
        entry(id: english, family: 'qwen', language: 'en'),
        entry(
          id: 'qwen-en-q8-desktop',
          family: 'qwen',
          language: 'en',
          minRamMb: 16384,
          contextTokens: 32768,
        ),
      ])),
    );

    final phone = selector.selectFor(language: 'en', deviceRamMb: 3072);
    final laptop = selector.selectFor(language: 'en', deviceRamMb: 32768);

    expect(
      laptop.promptBudgetTokens,
      greaterThan(phone.promptBudgetTokens),
    );
  });
}
