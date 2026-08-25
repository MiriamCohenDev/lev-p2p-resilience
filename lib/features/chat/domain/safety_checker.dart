/// What the safety layer concluded about one user message.
class SafetyVerdict {
  const SafetyVerdict.clear()
      : matched = false,
        supportMessage = null,
        patternId = null;

  const SafetyVerdict.acuteDistress({
    required String this.supportMessage,
    required String this.patternId,
  }) : matched = true;

  final bool matched;

  /// The fixed, model-independent text to surface.
  ///
  /// **Alongside the reply, never instead of it** (§5.2.4). Replacing the
  /// assistant's answer with a canned notice would tell a person in distress
  /// that saying the wrong thing gets them shut out of the conversation.
  final String? supportMessage;

  /// Which pattern matched, for the test corpus and for debugging. Never shown.
  final String? patternId;
}

/// Deterministic acute-distress detection (technical-spec §5.2.4).
///
/// Evaluated on the user's raw message **before** it reaches the model, and
/// deliberately not model-based. §5.2.4's rationale: a guarantee that depends on
/// the inference quality of a 4-bit model running on an old phone is not a
/// guarantee. This layer must behave identically whichever `LlmService` is
/// registered, and its test corpus must pass with any of them.
///
/// The patterns are an asset file, localised per UI language — the same message
/// must be caught in Hebrew and in English (§8's i18n requirement, #11).
abstract class SafetyChecker {
  SafetyVerdict evaluate(String userText);
}
