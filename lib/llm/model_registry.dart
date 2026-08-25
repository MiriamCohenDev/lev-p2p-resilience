import 'dart:convert';

import '../features/chat/domain/llm_errors.dart';
import 'model_descriptor.dart';

/// The models the app knows about (technical-spec §5.3).
///
/// Loaded from `assets/models/models.json`. The registry is **data, not code**:
/// adding a Hebrew model or a desktop-tier model is a manifest entry plus a
/// GGUF file, with no change under `features/chat`. Phase 3.3 verifies exactly
/// this, so resist adding per-model behaviour here.
class ModelRegistry {
  const ModelRegistry(this.models);

  /// Parses a manifest document.
  ///
  /// Kept separate from any asset loading so the parser is testable without a
  /// Flutter binding, and so the caller decides where the bytes came from.
  factory ModelRegistry.parse(String manifestJson) {
    final Object? decoded;
    try {
      decoded = jsonDecode(manifestJson);
    } on FormatException catch (error) {
      throw ModelManifestInvalid(
        'the models manifest is not valid JSON',
        cause: error,
      );
    }

    if (decoded is! Map<String, Object?>) {
      throw const ModelManifestInvalid(
        'the models manifest must be a JSON object with a "models" array',
      );
    }

    final entries = decoded['models'];
    if (entries is! List) {
      throw const ModelManifestInvalid(
        'the models manifest has no "models" array',
      );
    }

    final List<ModelDescriptor> models;
    try {
      models = entries
          .map((entry) => ModelDescriptor.fromJson(entry as Map<String, Object?>))
          .toList(growable: false);
    } on Object catch (error) {
      throw ModelManifestInvalid(
        'the models manifest contains a malformed entry',
        cause: error,
      );
    }

    if (models.isEmpty) {
      throw const ModelManifestInvalid(
        'the models manifest lists no models',
      );
    }

    final ids = models.map((m) => m.id).toSet();
    if (ids.length != models.length) {
      throw const ModelManifestInvalid(
        'the models manifest reuses a model id',
      );
    }

    return ModelRegistry(models);
  }

  final List<ModelDescriptor> models;

  ModelDescriptor? byId(String id) {
    for (final model in models) {
      if (model.id == id) return model;
    }
    return null;
  }
}

/// Picks the best model for this device and language (technical-spec §5.3).
abstract class ModelSelector {
  ModelDescriptor selectFor({
    required String language,
    required int deviceRamMb,
  });
}

/// The v1 selection strategy.
///
/// Among the models this device can actually run, prefer the requested
/// language, then the largest context window — a bigger window is what keeps a
/// long conversation off the summariser (§5.2.3).
///
/// Falling back to another language is deliberate and is the v1 reality: §10's
/// Hebrew gap means a Hebrew-reading user gets a Hebrew UI and an English
/// assistant (#11). Returning nothing instead would leave them with no chat at
/// all.
class DefaultModelSelector implements ModelSelector {
  const DefaultModelSelector(this._registry);

  final ModelRegistry _registry;

  @override
  ModelDescriptor selectFor({
    required String language,
    required int deviceRamMb,
  }) {
    // §8's min-spec gate. A model that does not fit does not "run slowly" — it
    // fails to load, or takes the app down with it.
    final runnable = _registry.models
        .where((model) => model.minRamMb <= deviceRamMb)
        .toList();

    if (runnable.isEmpty) {
      throw NoSuitableModel(
        'no model in the registry runs on a device with ${deviceRamMb}MB of '
        'RAM; the smallest needs '
        '${_registry.models.map((m) => m.minRamMb).reduce((a, b) => a < b ? a : b)}MB',
      );
    }

    final matching =
        runnable.where((model) => model.language == language).toList();
    final candidates = matching.isEmpty ? runnable : matching;

    candidates.sort((a, b) => b.contextTokens.compareTo(a.contextTokens));
    return candidates.first;
  }
}
