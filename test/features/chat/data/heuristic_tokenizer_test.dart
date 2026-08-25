import 'package:flutter_test/flutter_test.dart';
import 'package:lev/features/chat/data/heuristic_tokenizer.dart';

/// The heuristic's job is not accuracy — it is a safe direction of error.
/// §8 makes exceeding the context budget a defect, so under-counting is the
/// failure that matters and over-counting is the price paid to avoid it.
void main() {
  const tokenizer = HeuristicTokenizer();

  test('empty text costs nothing', () {
    expect(tokenizer.count(''), 0);
  });

  test('any non-empty text costs at least one token', () {
    expect(tokenizer.count('a'), greaterThanOrEqualTo(1));
    expect(tokenizer.count(' '), greaterThanOrEqualTo(1));
  });

  test('never under-counts a word', () {
    // No tokenizer merges across whitespace, so N words is a hard lower bound
    // however short they are. This is the case a characters-per-token estimate
    // alone gets wrong.
    final text = List.filled(50, 'a').join(' ');

    expect(tokenizer.count(text), greaterThanOrEqualTo(50));
  });

  test('grows with the text', () {
    final short = tokenizer.count('a short sentence');
    final long = tokenizer.count('a short sentence ' * 10);

    expect(long, greaterThan(short));
  });

  test('does not under-count Hebrew', () {
    // The UI is bilingual (#11) even while the model is English-only, and a
    // Hebrew message must not slip past the budget because its characters
    // happen to be cheaper by this estimate than by a real vocabulary.
    const hebrew = 'שלום, אני רוצה לדבר על משהו שקרה היום';

    expect(
      tokenizer.count(hebrew),
      greaterThanOrEqualTo(hebrew.split(' ').length),
    );
  });

  test('errs high rather than low on ordinary prose', () {
    // Roughly 4 characters per token is the real-world figure for English; the
    // heuristic must land at or above what that would predict.
    const prose =
        'That sounds like a lot to be carrying, and it makes sense to me.';

    expect(tokenizer.count(prose), greaterThanOrEqualTo(prose.length ~/ 4));
  });
}
