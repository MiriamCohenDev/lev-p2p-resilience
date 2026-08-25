/// A fully rendered, model-specific prompt ready for inference
/// (technical-spec §5.1).
///
/// By the time a [Prompt] exists, every model-specific decision has already been
/// made: the chat template for the active family has been applied (§5.2.2) and
/// the context budget has been enforced (§5.2.3). An `LlmService` receives text
/// and stop tokens and knows nothing about conversations, roles or budgets —
/// which is exactly what lets the engine be replaced without touching the chat.
class Prompt {
  const Prompt({
    required this.text,
    required this.stopTokens,
    required this.estimatedTokens,
  });

  /// Already templated for the active model.
  final String text;

  /// Where generation must stop, from `ModelDescriptor.stopTokens`.
  final List<String> stopTokens;

  /// What the active `Tokenizer` made of [text].
  ///
  /// "Estimated" is honest about Phase 2, where the tokenizer is a heuristic.
  /// Phase 3.1 swaps in the engine's real tokenizer and the number becomes
  /// exact, with no change to this class or its callers.
  final int estimatedTokens;

  @override
  String toString() => 'Prompt($estimatedTokens tokens, ${text.length} chars)';
}
