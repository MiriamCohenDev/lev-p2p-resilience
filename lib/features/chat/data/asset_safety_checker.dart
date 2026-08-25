import 'dart:convert';

import '../domain/safety_checker.dart';

/// One acute-distress pattern from the asset file.
class SafetyPattern {
  const SafetyPattern({required this.id, required this.expression});

  final String id;
  final RegExp expression;
}

/// A [SafetyChecker] driven by `assets/prompts/safety_patterns_<locale>.json`
/// (technical-spec §5.2.4).
///
/// Deterministic Dart, evaluated on the raw message **before** it reaches the
/// model, and identical whichever `LlmService` is registered. §5.2.4's
/// rationale: a guarantee that depends on the inference quality of a 4-bit model
/// running on an old phone is not a guarantee.
///
/// Patterns live in an asset, not in code, so the list can be tuned and
/// localised without a rebuild — and so the test corpus can pin the behaviour
/// that the UI depends on.
class AssetSafetyChecker implements SafetyChecker {
  const AssetSafetyChecker({
    required this.supportMessage,
    required this.patterns,
  });

  /// Parses one locale's pattern file.
  ///
  /// Separate from asset loading so it is testable without a Flutter binding,
  /// and so the caller decides where the bytes came from.
  factory AssetSafetyChecker.parse(String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException catch (error) {
      throw FormatException('safety patterns: not valid JSON', error.source);
    }

    if (decoded is! Map<String, Object?>) {
      throw const FormatException('safety patterns: expected a JSON object');
    }

    final supportMessage = decoded['supportMessage'];
    if (supportMessage is! String || supportMessage.trim().isEmpty) {
      throw const FormatException(
        'safety patterns: "supportMessage" is missing. A match with nothing to '
        'show is worse than no match at all.',
      );
    }

    final entries = decoded['patterns'];
    if (entries is! List || entries.isEmpty) {
      throw const FormatException('safety patterns: "patterns" is empty');
    }

    final patterns = <SafetyPattern>[];
    for (final entry in entries) {
      if (entry is! Map<String, Object?>) {
        throw const FormatException('safety patterns: malformed entry');
      }
      final id = entry['id'];
      final expression = entry['pattern'];
      if (id is! String || expression is! String) {
        throw const FormatException(
          'safety patterns: every entry needs an "id" and a "pattern"',
        );
      }
      patterns.add(
        SafetyPattern(
          id: id,
          // Case-insensitive because distress is not written in careful prose,
          // and unicode because half of these patterns are Hebrew.
          expression: RegExp(expression, caseSensitive: false, unicode: true),
        ),
      );
    }

    return AssetSafetyChecker(
      supportMessage: supportMessage,
      patterns: patterns,
    );
  }

  /// The fixed text shown on a match — the same every time, by design.
  final String supportMessage;

  final List<SafetyPattern> patterns;

  @override
  SafetyVerdict evaluate(String userText) {
    for (final pattern in patterns) {
      if (pattern.expression.hasMatch(userText)) {
        return SafetyVerdict.acuteDistress(
          supportMessage: supportMessage,
          patternId: pattern.id,
        );
      }
    }
    return const SafetyVerdict.clear();
  }
}

/// A checker that never matches.
///
/// Registered when no pattern file exists for the active UI language. Failing
/// open is the right direction here: the notice is supplementary — the model
/// still answers — so a missing list must not take the chat down with it. The
/// two shipped locales are covered by the corpus, so this is a fallback for a
/// language nobody has written patterns for yet, not an accepted state.
class NeverMatchingSafetyChecker implements SafetyChecker {
  const NeverMatchingSafetyChecker();

  @override
  SafetyVerdict evaluate(String userText) => const SafetyVerdict.clear();
}
