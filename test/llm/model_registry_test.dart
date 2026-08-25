import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:lev/core/di/llm_providers.dart';
import 'package:lev/features/chat/domain/llm_errors.dart';
import 'package:lev/llm/model_registry.dart';

/// The registry is data, not code (technical-spec §5.3), so these tests are
/// about the manifest contract: what a malformed one does, and how selection
/// behaves. Phase 3.3 will lean on exactly this.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, Object?> descriptor({
    String id = 'qwen-en-q4',
    String family = 'qwen',
    String language = 'en',
    int minRamMb = 3072,
    int contextTokens = 4096,
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
        'stopTokens': ['<|im_end|>'],
        'quantization': 'Q4_K_M',
      };

  String manifestOf(List<Map<String, Object?>> models) =>
      jsonEncode({'models': models});

  group('the bundled manifest', () {
    test('parses and describes exactly one English model', () async {
      final registry = ModelRegistry.parse(
        await rootBundle.loadString(modelsManifestAsset),
      );

      expect(registry.models, hasLength(1));
      final model = registry.models.single;
      expect(model.id, 'qwen-en-q4');
      expect(model.family, 'qwen');
      expect(model.language, 'en');
      // The budget PromptBuilder enforces has to be a positive number of tokens
      // or §5.2.3 has nothing to work with.
      expect(model.promptBudgetTokens, greaterThan(0));
      expect(model.stopTokens, isNotEmpty);
    });
  });

  group('parsing', () {
    test('rejects text that is not JSON', () {
      expect(
        () => ModelRegistry.parse('not json'),
        throwsA(isA<ModelManifestInvalid>()),
      );
    });

    test('rejects a manifest with no models array', () {
      expect(
        () => ModelRegistry.parse('{"somethingElse": []}'),
        throwsA(isA<ModelManifestInvalid>()),
      );
    });

    test('rejects an empty models array', () {
      expect(
        () => ModelRegistry.parse(manifestOf([])),
        throwsA(isA<ModelManifestInvalid>()),
      );
    });

    test('rejects an entry missing a required field', () {
      final broken = descriptor()..remove('contextTokens');

      expect(
        () => ModelRegistry.parse(manifestOf([broken])),
        throwsA(isA<ModelManifestInvalid>()),
      );
    });

    test('rejects a duplicated model id', () {
      expect(
        () => ModelRegistry.parse(
          manifestOf([descriptor(), descriptor(contextTokens: 8192)]),
        ),
        throwsA(isA<ModelManifestInvalid>()),
      );
    });
  });

  group('selection', () {
    test('prefers the requested language', () {
      final registry = ModelRegistry.parse(manifestOf([
        descriptor(id: 'en-model', language: 'en', minRamMb: 1024),
        descriptor(id: 'he-model', language: 'he', minRamMb: 1024),
      ]));

      final selected = DefaultModelSelector(registry)
          .selectFor(language: 'he', deviceRamMb: 4096);

      expect(selected.id, 'he-model');
    });

    test('refuses a model the device cannot run', () {
      final registry = ModelRegistry.parse(manifestOf([
        descriptor(id: 'big', minRamMb: 8192),
      ]));

      expect(
        () => DefaultModelSelector(registry)
            .selectFor(language: 'en', deviceRamMb: 2048),
        throwsA(isA<NoSuitableModel>()),
      );
    });

    test('gates on RAM before language', () {
      final registry = ModelRegistry.parse(manifestOf([
        descriptor(id: 'he-big', language: 'he', minRamMb: 8192),
        descriptor(id: 'en-small', language: 'en', minRamMb: 1024),
      ]));

      // A model that does not fit does not run slowly — it fails to load. Asking
      // for Hebrew must not return one the device cannot open.
      final selected = DefaultModelSelector(registry)
          .selectFor(language: 'he', deviceRamMb: 2048);

      expect(selected.id, 'en-small');
    });

    test('falls back across languages rather than returning nothing', () {
      // §10's Hebrew gap is the v1 reality: a Hebrew-reading user gets a Hebrew
      // UI and an English assistant (#11). No chat at all would be worse.
      final registry = ModelRegistry.parse(manifestOf([descriptor()]));

      final selected = DefaultModelSelector(registry)
          .selectFor(language: 'he', deviceRamMb: 4096);

      expect(selected.language, 'en');
    });

    test('prefers the largest context window among equals', () {
      final registry = ModelRegistry.parse(manifestOf([
        descriptor(id: 'small-ctx', contextTokens: 2048, minRamMb: 1024),
        descriptor(id: 'large-ctx', contextTokens: 8192, minRamMb: 1024),
      ]));

      final selected = DefaultModelSelector(registry)
          .selectFor(language: 'en', deviceRamMb: 4096);

      // A bigger window is what keeps a long conversation off the summariser
      // (§5.2.3).
      expect(selected.id, 'large-ctx');
    });
  });
}
