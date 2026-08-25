/// Everything the app needs to know about one model (technical-spec §5.3).
///
/// **This is data, not code.** The registry is loaded from a manifest under
/// `assets/models/`, so adding a Hebrew model or a larger desktop model is a
/// manifest entry plus a GGUF file — never a change under `features/chat`.
/// Phase 3.3 exists specifically to verify that claim, so nothing here may
/// acquire behaviour that a manifest cannot express.
///
/// Pure Dart with no platform or framework dependency, which is why the chat
/// domain may depend on it without breaking §3.2's inward-pointing rule.
class ModelDescriptor {
  const ModelDescriptor({
    required this.id,
    required this.family,
    required this.assetPath,
    required this.sha256,
    required this.language,
    required this.minRamMb,
    required this.contextTokens,
    required this.replyTokenReserve,
    required this.stopTokens,
    required this.quantization,
  });

  factory ModelDescriptor.fromJson(Map<String, Object?> json) {
    T require<T>(String key) {
      final value = json[key];
      if (value is! T) {
        throw FormatException(
          'models manifest: "$key" is missing or is not a $T',
          json.toString(),
        );
      }
      return value;
    }

    return ModelDescriptor(
      id: require<String>('id'),
      family: require<String>('family'),
      assetPath: require<String>('assetPath'),
      sha256: require<String>('sha256'),
      language: require<String>('language'),
      minRamMb: require<int>('minRamMb'),
      contextTokens: require<int>('contextTokens'),
      replyTokenReserve: require<int>('replyTokenReserve'),
      stopTokens: require<List<Object?>>('stopTokens').cast<String>(),
      quantization: require<String>('quantization'),
    );
  }

  /// e.g. `qwen-en-q4`.
  final String id;

  /// `qwen` | `llama` — selects the chat template (§5.2.2).
  ///
  /// A string rather than an enum: the whole point of the manifest is that a new
  /// family can be added as data. An unknown family fails when a template is
  /// requested for it, which is where the failure is actionable.
  final String family;

  /// Where the GGUF file lives. Not read until Phase 3.1.
  final String assetPath;

  /// Checked before load (§7.5). Unused in Phase 2 — there is no file to check.
  final String sha256;

  /// `en` in v1; `he` later (§10's open Hebrew gap).
  final String language;

  /// Device-capability gate, enforced by [ModelSelector].
  final int minRamMb;

  /// The model's context window.
  final int contextTokens;

  /// Held back for the reply, so the budget is `contextTokens - this`.
  final int replyTokenReserve;

  final List<String> stopTokens;

  /// e.g. `Q4_K_M`.
  final String quantization;

  /// What `PromptBuilder` must fit everything into (§5.2.3).
  int get promptBudgetTokens => contextTokens - replyTokenReserve;

  @override
  String toString() => 'ModelDescriptor($id, $family, $language)';
}
