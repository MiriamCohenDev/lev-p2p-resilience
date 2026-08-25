import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/chat/data/fake_llm_service.dart';
import '../../features/chat/data/heuristic_tokenizer.dart';
import '../../features/chat/domain/llm_service.dart';
import '../../features/chat/domain/tokenizer.dart';
import '../../llm/model_descriptor.dart';
import '../../llm/model_registry.dart';

/// Inference wiring. Hand-written providers, per technical-decisions #10.
///
/// The chain is several links for the same reason the crypto chain is: each one
/// is a seam. A test overrides [llmServiceProvider] to drive a specific failure
/// mode, or [modelRegistryProvider] to try a second model family, without
/// touching anything else.

/// Where the manifest lives (technical-spec §5.3).
const String modelsManifestAsset = 'assets/models/models.json';

/// The models this build knows about.
///
/// Loaded from an asset, not declared in Dart: §5.3 requires that adding a model
/// be a manifest entry plus a GGUF file, never a code change. Phase 3.3 tests
/// that claim, and a provider that hardcoded a descriptor would fail it.
final modelRegistryProvider = FutureProvider<ModelRegistry>((ref) async {
  return ModelRegistry.parse(await rootBundle.loadString(modelsManifestAsset));
});

/// How much RAM the selector may assume.
///
/// **A placeholder with a real seam.** §9's Phase 3.2 is where min-spec gating
/// is implemented against the actual device, because that is the first phase
/// where a model is loaded and the number means something. Until then this
/// reports a value that admits every descriptor, so Phase 2 is never blocked by
/// a gate it cannot yet measure. Overriding this provider is how Phase 3.2 will
/// replace it, and how a test explores the gate today.
final deviceRamMbProvider = Provider<int>((ref) => 1 << 20);

/// The language to prefer when selecting a model.
///
/// Not the UI locale. §10's Hebrew gap and #11 together mean a Hebrew-reading
/// user gets a Hebrew UI and an English assistant in v1; tying this to the
/// device locale would ask the registry for a model that does not exist.
final modelLanguageProvider = Provider<String>((ref) => 'en');

final modelSelectorProvider = FutureProvider<ModelSelector>((ref) async {
  return DefaultModelSelector(await ref.watch(modelRegistryProvider.future));
});

/// The descriptor the chat is currently held under.
///
/// Everything model-specific — the chat template, the context budget, the stop
/// tokens — is read from here, so a model swap moves through this one provider.
final activeModelProvider = FutureProvider<ModelDescriptor>((ref) async {
  final selector = await ref.watch(modelSelectorProvider.future);
  return selector.selectFor(
    language: ref.watch(modelLanguageProvider),
    deviceRamMb: ref.watch(deviceRamMbProvider),
  );
});

/// The token counter used for budget enforcement.
///
/// Phase 2 counts heuristically; Phase 3.1 replaces this binding with the
/// engine's own tokenizer (Appendix A). Exposed separately from
/// [llmServiceProvider] so `PromptBuilder` can be constructed and tested without
/// an engine at all.
final tokenizerProvider = Provider<Tokenizer>((ref) => const HeuristicTokenizer());

/// The inference engine.
///
/// **This is the Phase 3.1 swap point.** Replacing `FakeLlmService` with
/// `LlamaCppLlmService` here is the whole of the change §9 promises leaves chat
/// code untouched. Nothing above this provider may name the concrete type.
final llmServiceProvider = FutureProvider<LlmService>((ref) async {
  final service = FakeLlmService(tokenizer: ref.watch(tokenizerProvider));
  ref.onDispose(service.unload);
  await service.loadModel(await ref.watch(activeModelProvider.future));
  return service;
});
