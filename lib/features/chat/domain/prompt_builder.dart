import '../../../llm/model_descriptor.dart';
import 'conversation.dart';
import 'message.dart';
import 'prompt.dart';

/// Assembles model-specific prompts within the context budget
/// (technical-spec §5.2.3).
///
/// This is where the product's actual behaviour lives, and it is deliberately
/// pure Dart: the chat template (§5.2.2) and the budget policy stay out of the
/// engine, which is what makes engines and models interchangeable. §4 states the
/// rejected alternative plainly — letting the engine format raw history leaks
/// model knowledge into the engine implementation, and a model swap becomes an
/// engine rewrite instead of a manifest edit.
///
/// Assembly order, highest priority first:
/// 1. **System prompt** — always present, never truncated.
/// 2. **Rolling summary** — a condensed record of turns that no longer fit.
/// 3. **Recent turns** — as many trailing messages as the remaining budget
///    allows.
///
/// The budget is `contextTokens - replyTokenReserve` from the active descriptor.
/// Exceeding it is a **defect** (§8), not a graceful degradation: the engine
/// responds by silently truncating the system prompt, which removes the
/// assistant's limits without removing the appearance that it has any.
abstract class PromptBuilder {
  /// The full conversation seed used to open a session.
  Prompt buildSeed(
    Conversation conversation,
    List<Message> history,
    ModelDescriptor model,
  );

  /// A single incremental turn appended to an already-open session.
  ///
  /// Only the new tokens: the session already holds everything [buildSeed] put
  /// in it, and re-sending history would defeat the KV cache the session exists
  /// for (§5.1).
  Prompt buildTurn(Message userMessage, ModelDescriptor model);

  /// The oldest turns that no longer fit, in order.
  ///
  /// One method wider than §5.1's illustrative sketch, and necessarily so:
  /// §5.2.3 requires the turns that fall out of the window to be folded into the
  /// rolling summary, and something has to say *which* turns those are. Deciding
  /// it anywhere but here would mean two places computing the same budget and
  /// eventually disagreeing — at which point turns are either summarised twice
  /// or lost entirely.
  ///
  /// Empty while the whole conversation still fits.
  List<Message> overflow(
    Conversation conversation,
    List<Message> history,
    ModelDescriptor model,
  );
}
