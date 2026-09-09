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
    this.sizeBytes,
    this.attribution,
    this.licenseAsset,
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
      // Optional, and read leniently: it is shown to the user and never acted
      // on, so a manifest without it should still load.
      sizeBytes: json['sizeBytes'] is int ? json['sizeBytes']! as int : null,
      attribution:
          json['attribution'] is String ? json['attribution']! as String : null,
      licenseAsset: json['licenseAsset'] is String
          ? json['licenseAsset']! as String
          : null,
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

  /// The GGUF's size on disk, for the Settings screen.
  ///
  /// Declared in the manifest rather than measured, and that is not laziness:
  /// `ModelFileStore.pathFor` verifies the digest by streaming the whole file,
  /// so asking it for a path merely to call `length()` would re-hash several
  /// hundred megabytes every time Settings is opened. Nothing depends on this
  /// value being right — it is displayed, never enforced — so a stale number
  /// misinforms rather than breaks, and it sits beside the `sha256` that *is*
  /// enforced.
  ///
  /// Nullable: a manifest entry without it simply shows no size.
  final int? sizeBytes;

  /// The one line the model's licence obliges the product to show, verbatim.
  ///
  /// e.g. `Qwen2.5-0.5B-Instruct · © Alibaba Cloud · Apache License 2.0`.
  /// Shown in the About section beneath the active model.
  ///
  /// **Data, not a translated string.** It is in the manifest and not in an ARB
  /// file for two reasons: a second model arrives with a different licence and
  /// that must not be a code change (§5.3), and a licence notice is not
  /// interface copy — translating an attribution is how it stops being the
  /// notice the licence asked for.
  ///
  /// Nullable, and read leniently, so a manifest written before this field
  /// still loads. A model with no attribution simply shows none.
  final String? attribution;

  /// The bundled licence text for these weights, e.g.
  /// `assets/licenses/qwen-en-q4-license.txt`.
  ///
  /// Registered with `LicenseRegistry` at startup so it reaches the licence
  /// page. That page collects **pub packages** on its own and knows nothing
  /// about assets, so a bundled model would otherwise be the one dependency
  /// with a real obligation that never appears there.
  final String? licenseAsset;

  /// The size in whole tenths of a gigabyte, as Settings writes it, or `null`
  /// when [sizeBytes] is absent. Decimal GB, matching what an installer reports.
  String? get sizeInGigabytes => sizeBytes == null
      ? null
      : (sizeBytes! / 1000000000).toStringAsFixed(1);

  /// What `PromptBuilder` must fit everything into (§5.2.3).
  int get promptBudgetTokens => contextTokens - replyTokenReserve;

  @override
  String toString() => 'ModelDescriptor($id, $family, $language)';
}
