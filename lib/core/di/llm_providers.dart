import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/chat/data/calibrated_tokenizer.dart';
import '../../features/chat/data/llama_cpp_llm_service.dart';
import '../../features/chat/domain/llm_service.dart';
import '../../features/chat/domain/tokenizer.dart';
import '../../llm/model_descriptor.dart';
import '../../llm/model_file_store.dart';
import '../../llm/model_registry.dart';
import '../platform/device_memory.dart';
import 'prompt_providers.dart';

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
/// **Phase 3.2's replacement of the Phase 2 placeholder.** Phase 2 reported a
/// value that admitted every descriptor, because nothing was loaded and the
/// number could not mean anything. It means something now: §8 makes the
/// min-spec gate the difference between a model that runs and one that fails to
/// load or takes the app down with it.
///
/// When the platform cannot be measured, the gate is opened rather than closed.
/// Being unable to *read* the RAM figure is not evidence that there is too
/// little of it, and refusing to start a chat on that basis would turn a missing
/// `/proc` into a broken app. The failure that follows — a model that will not
/// load — is at least reported against the real cause.
final deviceRamMbProvider = Provider<int>((ref) {
  return totalPhysicalMemoryMb() ?? _unmeasuredRamMb;
});

/// Stands in when the device's RAM cannot be read. Admits every descriptor.
const int _unmeasuredRamMb = 1 << 20;

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

/// Where the GGUF weights live once installed.
///
/// The application support directory, not the documents directory: these are
/// not the user's files, they are the app's, and on desktop the documents
/// directory is somewhere a person keeps their own things.
final modelFileStoreProvider = FutureProvider<ModelFileStore>((ref) async {
  final support = await getApplicationSupportDirectory();
  return InstalledModelFileStore(
    directory: Directory(p.join(support.path, 'models')),
  );
});

/// The inference engine.
///
/// **This is the Phase 3.1 swap, made.** `FakeLlmService` was registered here
/// through the whole of Phase 2 and the chat was built and finished against it;
/// replacing it with [LlamaCppLlmService] is the change §9 promises leaves chat
/// code untouched. Nothing above this provider names the concrete type, and
/// `features/chat/presentation` was not edited at all. The domain changed only
/// additively — see the class comment on [LlamaCppLlmService] for the exact
/// accounting, which is kept honest rather than round.
///
/// The fake has not been deleted. It is still what the widget tests drive the
/// UI's loading and failure states with (#16: it is a product decision, not a
/// test double), and it is still the only way to exercise the chat on a machine
/// with no weights installed.
final llmServiceProvider = FutureProvider<LlmService>((ref) async {
  final service = LlamaCppLlmService(
    fileStore: await ref.watch(modelFileStoreProvider.future),
    // The system prompt is the one long piece of text we know the model will
    // actually be shown, so it is the honest thing to measure the vocabulary's
    // tokens-per-character against. See `CalibratedTokenizer`.
    calibrationSamples: [
      (await ref.watch(systemPromptProvider.future)).text,
    ],
  );
  ref.onDispose(service.dispose);
  await service.loadModel(await ref.watch(activeModelProvider.future));
  return service;
});

/// The token counter used for budget enforcement.
///
/// Now the loaded model's own, calibrated against its vocabulary at load time —
/// Phase 2 counted with a fixed heuristic constant. It is read off the engine
/// rather than constructed here, because only the engine knows which model is
/// loaded and therefore which vocabulary the count refers to.
///
/// Kept as a separate provider so `PromptBuilder` can still be constructed and
/// tested without an engine at all; a test overrides this one and never touches
/// llama.cpp.
final tokenizerProvider = Provider<Tokenizer>((ref) {
  return ref.watch(llmServiceProvider).maybeWhen(
        data: (service) => service.tokenizer,
        orElse: () => const CalibratedTokenizer.uncalibrated(),
      );
});
