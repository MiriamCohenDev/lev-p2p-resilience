import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/chat/data/asset_safety_checker.dart';
import '../../features/chat/data/conversation_summariser.dart';
import '../../features/chat/data/default_prompt_builder.dart';
import '../../features/chat/data/system_prompt.dart';
import '../../features/chat/domain/safety_checker.dart';
import '../support/support_resources.dart';
import 'llm_providers.dart';

/// The prompt layer's wiring (technical-spec §5.2). Hand-written providers, per
/// technical-decisions #10.

const String systemPromptAsset = 'assets/prompts/system_prompt.md';

String safetyPatternsAsset(String languageCode) =>
    'assets/prompts/safety_patterns_$languageCode.json';

/// Locales with a safety pattern list in `assets/prompts/`.
const Set<String> safetyLocales = {'en', 'he'};

/// The versioned system prompt (§5.2.1).
///
/// Loaded from an asset at runtime and never a string literal, so the
/// assistant's voice and limits can be tuned without recompiling.
final systemPromptProvider = FutureProvider<SystemPrompt>((ref) async {
  return SystemPrompt.parse(await rootBundle.loadString(systemPromptAsset));
});

/// The UI language, which is what the safety layer is localised for.
///
/// Not the model's language: §10's Hebrew gap means a Hebrew-reading user gets a
/// Hebrew UI and an English assistant (#11), and the safety layer follows the
/// person, not the model. Overridden from the widget tree, which is the only
/// place the real locale is known.
final safetyLocaleProvider = Provider<Locale>((ref) => const Locale('en'));

/// What the support card says, and the number it dials (technical-decisions
/// #24).
///
/// Localised for the person in front of the screen, exactly like
/// [safetyCheckerProvider] and for the same reason. The content is an asset
/// rather than a string in the pattern file so that a number can be corrected
/// without a rebuild.
final supportResourceProvider = FutureProvider<LevSupportResource>((ref) async {
  return LevSupportResources.load(ref.watch(safetyLocaleProvider).languageCode);
});

/// Deterministic acute-distress detection (§5.2.4).
final safetyCheckerProvider = FutureProvider<SafetyChecker>((ref) async {
  final language = ref.watch(safetyLocaleProvider).languageCode;
  if (!safetyLocales.contains(language)) {
    // Fails open, and only for a language nobody has written patterns for: the
    // notice is supplementary — the model still answers — so a missing list must
    // not take the chat down with it.
    return const NeverMatchingSafetyChecker();
  }
  return AssetSafetyChecker.parse(
    await rootBundle.loadString(safetyPatternsAsset(language)),
  );
});

/// Folds turns that fall out of the context window into the rolling summary
/// (§5.2.3).
final conversationSummariserProvider = Provider<ConversationSummariser>((ref) {
  return ConversationSummariser(tokenizer: ref.watch(tokenizerProvider));
});

/// Prompt assembly: system prompt, rolling summary, recent turns, within budget.
final promptBuilderProvider = FutureProvider<DefaultPromptBuilder>((ref) async {
  return DefaultPromptBuilder(
    systemPrompt: await ref.watch(systemPromptProvider.future),
    tokenizer: ref.watch(tokenizerProvider),
  );
});
