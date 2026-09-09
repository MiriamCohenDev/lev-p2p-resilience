import 'package:flutter_test/flutter_test.dart';
import 'package:lev/features/chat/data/default_prompt_builder.dart';
import 'package:lev/features/chat/data/calibrated_tokenizer.dart';
import 'package:lev/features/chat/data/system_prompt.dart';
import 'package:lev/features/chat/domain/conversation.dart';
import 'package:lev/features/chat/domain/llm_errors.dart';
import 'package:lev/features/chat/domain/message.dart';
import 'package:lev/llm/model_descriptor.dart';

/// The context policy (technical-spec §5.2.3) and the §9 2.3 done-criteria.
///
/// Pure Dart with no engine anywhere near it — which is the point: §5.2 says
/// this layer is the product's actual behaviour and is engine-independent, so it
/// is finished and tested before any model exists.
void main() {
  const tokenizer = CalibratedTokenizer.uncalibrated();
  const systemPrompt = SystemPrompt(
    version: '1.0.0',
    text: 'You are LEV. Be calm, honest and brief.',
  );
  const builder = DefaultPromptBuilder(
    systemPrompt: systemPrompt,
    tokenizer: tokenizer,
  );

  ModelDescriptor model({
    String family = 'qwen',
    int contextTokens = 4096,
    int replyTokenReserve = 512,
  }) =>
      ModelDescriptor(
        id: 'test-$family-$contextTokens',
        family: family,
        assetPath: '',
        sha256: '',
        language: 'en',
        minRamMb: 0,
        contextTokens: contextTokens,
        replyTokenReserve: replyTokenReserve,
        stopTokens: const ['<|im_end|>'],
        quantization: 'Q4_K_M',
      );

  Conversation conversation({String? summary}) => Conversation(
        id: 'c1',
        title: 'test',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        summary: summary,
      );

  /// [count] alternating turns, oldest first, each distinctly identifiable.
  List<Message> history(int count, {int wordsEach = 5}) => [
        for (var i = 0; i < count; i++)
          if (i.isEven)
            Message.fromUserInput(
              conversationId: 'c1',
              text: 'user$i ${List.filled(wordsEach, 'word$i').join(' ')}',
              id: 'm$i',
              createdAt: DateTime.utc(2026).add(Duration(minutes: i)),
            )
          else
            Message.fromAssistant(
              conversationId: 'c1',
              text: 'assistant$i ${List.filled(wordsEach, 'word$i').join(' ')}',
              id: 'm$i',
              createdAt: DateTime.utc(2026).add(Duration(minutes: i)),
            ),
      ];

  group('assembly order', () {
    test('the system prompt is always present', () {
      final prompt = builder.buildSeed(conversation(), [], model());

      expect(prompt.text, contains(systemPrompt.text));
    });

    test('the summary is included and labelled as a summary', () {
      final prompt = builder.buildSeed(
        conversation(summary: 'They have been struggling with sleep.'),
        history(2),
        model(),
      );

      expect(prompt.text, contains('They have been struggling with sleep.'));
      // Labelled, so the model does not read a third-person record as something
      // the user just said.
      expect(prompt.text, contains('Summary of the earlier part'));
    });

    test('the summary comes before the recent turns', () {
      final prompt = builder.buildSeed(
        conversation(summary: 'EARLIER-CONTEXT'),
        history(2),
        model(),
      );

      expect(
        prompt.text.indexOf('EARLIER-CONTEXT'),
        lessThan(prompt.text.indexOf('user0')),
      );
    });

    test('a conversation with no summary carries no summary block', () {
      final prompt = builder.buildSeed(conversation(), history(2), model());

      expect(prompt.text, isNot(contains('Summary of the earlier part')));
    });

    test('the prompt ends by handing the floor to the assistant', () {
      final prompt = builder.buildSeed(conversation(), history(2), model());

      // Without this the model continues as the *user*, inventing the next
      // message instead of answering.
      expect(prompt.text, endsWith('<|im_start|>assistant\n'));
    });
  });

  group('budget enforcement', () {
    test('never exceeds contextTokens - replyTokenReserve', () {
      // §8: exceeding the budget is a defect, not a degradation. Swept across
      // many lengths because the interesting case is the boundary, and a single
      // fixture would sit on one side of it forever.
      for (final turns in [0, 1, 2, 5, 20, 100, 400]) {
        final m = model(contextTokens: 1024, replyTokenReserve: 256);
        final prompt = builder.buildSeed(conversation(), history(turns), m);

        expect(
          prompt.estimatedTokens,
          lessThanOrEqualTo(m.promptBudgetTokens),
          reason: '$turns turns overflowed the budget',
        );
      }
    });

    test('holds under a long summary as well', () {
      final m = model(contextTokens: 1024, replyTokenReserve: 256);
      final prompt = builder.buildSeed(
        conversation(summary: List.filled(300, 'summary').join(' ')),
        history(50),
        m,
      );

      expect(prompt.estimatedTokens, lessThanOrEqualTo(m.promptBudgetTokens));
    });

    test('the system prompt is never truncated to make room', () {
      final prompt = builder.buildSeed(
        conversation(),
        history(400),
        model(contextTokens: 1024, replyTokenReserve: 256),
      );

      // Priority 1, and the reason the whole policy exists: a truncated system
      // prompt removes the assistant's stated limits while leaving it sounding
      // exactly as confident.
      expect(prompt.text, contains(systemPrompt.text));
    });

    test('keeps the newest turns and drops the oldest', () {
      final turns = history(200);
      final prompt = builder.buildSeed(
        conversation(),
        turns,
        model(contextTokens: 1024, replyTokenReserve: 256),
      );

      expect(prompt.text, contains('word199'), reason: 'newest must survive');
      expect(prompt.text, isNot(contains('word0 ')));
    });

    test('a system prompt that cannot fit fails loudly', () {
      final huge = SystemPrompt(
        version: '1',
        text: List.filled(4000, 'word').join(' '),
      );
      final bigBuilder =
          DefaultPromptBuilder(systemPrompt: huge, tokenizer: tokenizer);

      // Refusing beats answering without the assistant's limits (§8).
      expect(
        () => bigBuilder.buildSeed(conversation(), [], model()),
        throwsA(isA<ModelUnavailable>()),
      );
    });
  });

  group('overflow', () {
    test('is empty while the whole conversation fits', () {
      expect(builder.overflow(conversation(), history(3), model()), isEmpty);
    });

    test('is the oldest turns, in order, when it does not', () {
      final turns = history(200);
      final overflow = builder.overflow(
        conversation(),
        turns,
        model(contextTokens: 1024, replyTokenReserve: 256),
      );

      expect(overflow, isNotEmpty);
      expect(overflow.first.id, 'm0', reason: 'oldest first');
      // A prefix of the history: anything else would summarise turns that are
      // still in the window, or lose turns between the two.
      expect(
        overflow.map((m) => m.id),
        turns.take(overflow.length).map((m) => m.id),
      );
    });

    test('agrees exactly with what buildSeed left out', () {
      final turns = history(200);
      final m = model(contextTokens: 1024, replyTokenReserve: 256);

      final overflow = builder.overflow(conversation(), turns, m);
      final prompt = builder.buildSeed(conversation(), turns, m);

      // The two must not disagree: a turn in neither is lost outright, and a
      // turn in both is summarised while still being carried verbatim.
      for (final message in overflow) {
        expect(prompt.text, isNot(contains(message.text)));
      }
      for (final message in turns.skip(overflow.length)) {
        expect(prompt.text, contains(message.text));
      }
    });
  });

  group('per-family templating (the §9 2.3 done-criterion)', () {
    test('the same conversation renders differently per family', () {
      final qwen = builder.buildSeed(conversation(), history(2), model());
      final llama = builder.buildSeed(
        conversation(),
        history(2),
        model(family: 'llama'),
      );

      expect(qwen.text, isNot(llama.text));
      expect(qwen.text, contains('<|im_start|>'));
      expect(llama.text, contains('<|start_header_id|>'));
      // Only the *rendering* changes; the conversation is the same.
      expect(qwen.text, contains('user0'));
      expect(llama.text, contains('user0'));
    });

    test('an unknown family fails with an actionable message', () {
      expect(
        () => builder.buildSeed(
          conversation(),
          history(2),
          model(family: 'mystery'),
        ),
        throwsA(
          isA<ModelUnavailable>().having(
            (e) => e.message,
            'message',
            allOf(contains('mystery'), contains('models.json')),
          ),
        ),
      );
    });
  });

  group('buildTurn', () {
    test('carries only the new turn, not the history', () {
      final turns = history(4);
      final turn = builder.buildTurn(turns.last, model());

      // The session already holds the seed; re-sending it would defeat the KV
      // cache the session exists for (§5.1).
      expect(turn.text, contains(turns.last.text));
      expect(turn.text, isNot(contains(systemPrompt.text)));
      expect(turn.text, isNot(contains(turns.first.text)));
    });

    test('hands the floor to the assistant', () {
      final turn = builder.buildTurn(history(1).single, model());

      expect(turn.text, endsWith('<|im_start|>assistant\n'));
    });

    test('carries the model\'s stop tokens', () {
      final turn = builder.buildTurn(history(1).single, model());

      expect(turn.stopTokens, ['<|im_end|>']);
    });
  });
}
