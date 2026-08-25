import '../../../llm/model_descriptor.dart';
import '../domain/conversation.dart';
import '../domain/message.dart';
import '../domain/message_role.dart';
import '../domain/prompt.dart';
import '../domain/prompt_builder.dart';
import '../domain/tokenizer.dart';

/// A [PromptBuilder] with no context policy — **replaced in Phase 2.3**.
///
/// It exists because §9's 2.2 and 2.3 are separable in the spec but not in the
/// type system: `LlmSession.send` takes a `Prompt`, so the chat cannot be wired
/// end-to-end until *something* renders one. This is that something, and
/// nothing more.
///
/// What it deliberately does **not** do, all of which arrives in 2.3 (§5.2):
/// - load the versioned system prompt from `assets/prompts/`
/// - apply a per-family chat template
/// - enforce the token budget, or fold old turns into a rolling summary
///
/// The token count is real, because [Prompt.estimatedTokens] is used for
/// nothing else yet and a fabricated number would be a lie waiting to be
/// trusted.
class ProvisionalPromptBuilder implements PromptBuilder {
  const ProvisionalPromptBuilder(this._tokenizer);

  final Tokenizer _tokenizer;

  @override
  Prompt buildSeed(
    Conversation conversation,
    List<Message> history,
    ModelDescriptor model,
  ) {
    final text = history.map(_render).join('\n');
    return Prompt(
      text: text,
      stopTokens: model.stopTokens,
      estimatedTokens: _tokenizer.count(text),
    );
  }

  @override
  Prompt buildTurn(Message userMessage, ModelDescriptor model) {
    final text = _render(userMessage);
    return Prompt(
      text: text,
      stopTokens: model.stopTokens,
      estimatedTokens: _tokenizer.count(text),
    );
  }

  /// Role-tagged plain text. Not a chat template — §5.2.2's templates are
  /// per-family and belong to `lib/llm/chat_templates.dart` in 2.3.
  String _render(Message message) => switch (message.role) {
        MessageRole.user => 'User: ${message.text}',
        MessageRole.assistant => 'Assistant: ${message.text}',
        MessageRole.system => message.text,
      };
}
