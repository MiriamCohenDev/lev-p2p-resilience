import '../../../llm/chat_templates.dart';
import '../../../llm/model_descriptor.dart';
import '../domain/conversation.dart';
import '../domain/llm_errors.dart';
import '../domain/message.dart';
import '../domain/message_role.dart';
import '../domain/prompt.dart';
import '../domain/prompt_builder.dart';
import '../domain/tokenizer.dart';
import 'system_prompt.dart';

/// The context policy (technical-spec §5.2.3).
///
/// Assembly order, highest priority first:
/// 1. **System prompt** — always present, never truncated.
/// 2. **Rolling summary** — a condensed record of turns that no longer fit.
/// 3. **Recent turns** — as many trailing messages as the remaining budget
///    allows.
///
/// Everything here is pure Dart against an injected [Tokenizer] and a
/// [ChatTemplate] chosen by `ModelDescriptor.family`. No engine is involved,
/// which is what makes §9's 2.3 claim testable: changing the descriptor's family
/// changes the rendered prompt with no change under `features/chat`.
class DefaultPromptBuilder implements PromptBuilder {
  const DefaultPromptBuilder({
    required this.systemPrompt,
    required this.tokenizer,
  });

  final SystemPrompt systemPrompt;
  final Tokenizer tokenizer;

  /// Labels the summary block so the model does not read a condensed third-person
  /// record as something the user just said.
  static const String _summaryHeading =
      'Summary of the earlier part of this conversation:';

  @override
  Prompt buildSeed(
    Conversation conversation,
    List<Message> history,
    ModelDescriptor model,
  ) {
    final template = ChatTemplate.forFamily(model.family);
    final fit = _fit(conversation, history, model, template);

    final buffer = StringBuffer()
      ..write(template.preamble)
      ..write(fit.systemBlock)
      ..write(fit.summaryBlock);
    for (final message in fit.retained) {
      buffer.write(template.turn(message.role, message.text));
    }
    buffer.write(template.assistantCue);

    return _prompt(buffer.toString(), model);
  }

  @override
  Prompt buildTurn(Message userMessage, ModelDescriptor model) {
    final template = ChatTemplate.forFamily(model.family);
    // No preamble and no system prompt: the session already holds both, and
    // re-sending them would defeat the KV cache the session exists for (§5.1).
    final text = template.turn(userMessage.role, userMessage.text) +
        template.assistantCue;
    return _prompt(text, model);
  }

  @override
  List<Message> overflow(
    Conversation conversation,
    List<Message> history,
    ModelDescriptor model,
  ) =>
      _fit(
        conversation,
        history,
        model,
        ChatTemplate.forFamily(model.family),
      ).overflow;

  Prompt _prompt(String text, ModelDescriptor model) => Prompt(
        text: text,
        stopTokens: model.stopTokens,
        estimatedTokens: tokenizer.count(text),
      );

  /// Divides [history] into what fits and what has to be summarised.
  ///
  /// One place, used by both [buildSeed] and [overflow], so the prompt and the
  /// summariser can never disagree about where the line falls.
  _Fit _fit(
    Conversation conversation,
    List<Message> history,
    ModelDescriptor model,
    ChatTemplate template,
  ) {
    final budget = model.promptBudgetTokens;

    final systemBlock =
        template.turn(MessageRole.system, systemPrompt.text);
    final fixedCost = tokenizer.count(template.preamble) +
        tokenizer.count(systemBlock) +
        tokenizer.count(template.assistantCue);

    if (fixedCost >= budget) {
      // §8: exceeding the budget is a defect, not a graceful degradation — the
      // engine's response is to silently truncate the system prompt, which
      // removes the assistant's stated limits while leaving it sounding just as
      // confident. Better to refuse loudly than to answer without them.
      throw ModelUnavailable(
        'the system prompt needs $fixedCost tokens but model "${model.id}" '
        'leaves only $budget for the whole prompt. Shorten '
        'assets/prompts/system_prompt.md, or raise contextTokens / lower '
        'replyTokenReserve in the models manifest.',
      );
    }

    var remaining = budget - fixedCost;

    var summaryBlock = '';
    final summary = conversation.summary;
    if (summary != null && summary.trim().isNotEmpty) {
      final block = template.turn(
        MessageRole.system,
        '$_summaryHeading\n${summary.trim()}',
      );
      final cost = tokenizer.count(block);
      // Priority 2, so it goes in ahead of any recent turn — but it is capped
      // when written (see ConversationSummariser), so not fitting means the cap
      // and the budget disagree, and dropping it beats emitting an over-budget
      // prompt.
      if (cost < remaining) {
        summaryBlock = block;
        remaining -= cost;
      }
    }

    // Newest first: the most recent turns are the ones that must survive.
    final retained = <Message>[];
    var index = history.length - 1;
    for (; index >= 0; index--) {
      final message = history[index];
      final cost =
          tokenizer.count(template.turn(message.role, message.text));
      if (cost > remaining) break;
      remaining -= cost;
      retained.add(message);
    }

    return _Fit(
      systemBlock: systemBlock,
      summaryBlock: summaryBlock,
      retained: retained.reversed.toList(growable: false),
      overflow: history.sublist(0, index + 1),
    );
  }
}

class _Fit {
  const _Fit({
    required this.systemBlock,
    required this.summaryBlock,
    required this.retained,
    required this.overflow,
  });

  final String systemBlock;
  final String summaryBlock;

  /// Carried verbatim, oldest first.
  final List<Message> retained;

  /// Fell out of the window, oldest first. Destined for the rolling summary.
  final List<Message> overflow;
}
