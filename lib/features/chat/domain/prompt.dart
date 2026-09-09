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
    this.assistantSuffix = '',
  });

  /// Already templated for the active model.
  final String text;

  /// Where generation must stop, from `ModelDescriptor.stopTokens`.
  final List<String> stopTokens;

  /// What closes the assistant's turn once generation has finished.
  ///
  /// An opaque string as far as the engine is concerned. A real session keeps a
  /// running transcript so llama.cpp can match its prefix against the KV cache
  /// (§5.1), and the reply has to be closed off in that transcript before the
  /// next turn is appended — otherwise the conversation stays mid-turn and the
  /// model starts answering as the user. The value comes from the active
  /// family's `ChatTemplate`, so the engine still knows nothing about templates
  /// (#16).
  ///
  /// Defaults to empty because `FakeLlmService` has no transcript to close, and
  /// Phase 2's tests construct prompts directly.
  final String assistantSuffix;

  /// What the active `Tokenizer` made of [text].
  ///
  /// "Estimated" stays honest in Phase 3. The count is now measured against the
  /// loaded model's own vocabulary rather than a fixed constant, but it is still
  /// an estimate rather than llama.cpp's exact count — technical-decisions #20
  /// explains why the exact one is not affordable per message, and why the error
  /// is kept pointing at over-counting.
  final int estimatedTokens;

  @override
  String toString() => 'Prompt($estimatedTokens tokens, ${text.length} chars)';
}
