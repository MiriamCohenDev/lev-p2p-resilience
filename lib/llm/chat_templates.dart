import '../features/chat/domain/llm_errors.dart';
import '../features/chat/domain/message_role.dart';

/// Renders a conversation in one model family's format (technical-spec §5.2.2).
///
/// **Applied by `PromptBuilder`, never by the engine.** §4 states the rejected
/// alternative plainly: an engine that formats raw history has to know every
/// model's conventions, so swapping models becomes an engine rewrite instead of
/// a manifest edit. Everything here is pure string work with no engine anywhere
/// near it, which is what makes Phase 3.3's claim testable.
abstract class ChatTemplate {
  const ChatTemplate();

  /// Opens the conversation. Some families require a preamble before the first
  /// turn; most do not.
  String get preamble => '';

  /// One turn, complete with the family's role markers.
  String turn(MessageRole role, String text);

  /// The marker that hands the floor to the assistant.
  ///
  /// Appended after the last user turn so the model continues as the assistant
  /// rather than inventing another user message.
  String get assistantCue;

  /// The marker that takes the floor back once the assistant has finished.
  ///
  /// Phase 3 needs this and Phase 2 did not, because the fake engine never had a
  /// transcript to keep. A real session does: llama.cpp reuses the KV cache by
  /// matching the prefix of the prompt it is given (§5.1), so the session has to
  /// append each reply to the running transcript before the next turn — and a
  /// reply appended without its closing marker leaves the conversation
  /// permanently mid-assistant-turn, after which the model answers as the user.
  ///
  /// It lives here, with the rest of the family's markers, rather than in the
  /// engine: #16's whole point is that an engine which knows one model's
  /// conventions has to know all of them, and a model swap then becomes an
  /// engine rewrite. The engine receives this as a string on [Prompt] and never
  /// learns what it means.
  String get assistantSuffix;

  /// The template for [family], or a [ModelUnavailable] naming what is missing.
  ///
  /// Failing here rather than at manifest-load time is deliberate: an unknown
  /// family is only a problem for a model that is actually selected, and the
  /// error can then name the family and the point of use.
  static ChatTemplate forFamily(String family) => switch (family) {
        'qwen' => const ChatMlTemplate(),
        'llama' => const Llama3Template(),
        _ => throw ModelUnavailable(
            'no chat template for model family "$family". Add one in '
            'lib/llm/chat_templates.dart, or correct the family in '
            'assets/models/models.json.',
          ),
      };
}

/// ChatML — Qwen and most of its relatives.
class ChatMlTemplate extends ChatTemplate {
  const ChatMlTemplate();

  @override
  String turn(MessageRole role, String text) =>
      '<|im_start|>${role.wireName}\n$text<|im_end|>\n';

  @override
  String get assistantCue => '<|im_start|>assistant\n';

  @override
  String get assistantSuffix => '<|im_end|>\n';
}

/// The Llama 3 instruct format.
class Llama3Template extends ChatTemplate {
  const Llama3Template();

  @override
  String get preamble => '<|begin_of_text|>';

  @override
  String turn(MessageRole role, String text) =>
      '<|start_header_id|>${role.wireName}<|end_header_id|>\n\n'
      '$text<|eot_id|>';

  @override
  String get assistantCue =>
      '<|start_header_id|>assistant<|end_header_id|>\n\n';

  @override
  String get assistantSuffix => '<|eot_id|>';
}
