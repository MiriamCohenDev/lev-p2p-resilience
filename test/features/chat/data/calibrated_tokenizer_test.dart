import 'package:flutter_test/flutter_test.dart';
import 'package:lev/features/chat/data/calibrated_tokenizer.dart';

/// Long enough to clear `CalibratedTokenizer`'s minimum sample length, and
/// deliberately in the register the chat actually carries.
const String _prose =
    'That sounds like a lot to be carrying right now. Tell me what feels '
    'heaviest, and we can look at it one piece at a time rather than all at '
    'once. Nothing you have described sounds unreasonable to me.';

void main() {
  group('counting', () {
    test('an empty string costs nothing', () {
      expect(const CalibratedTokenizer.uncalibrated().count(''), 0);
    });

    test('a tighter ratio yields a higher count', () {
      // The whole point of calibrating. A vocabulary that produces more tokens
      // per character must produce a larger estimate for the same text,
      // otherwise the budget is enforced against the wrong model.
      final loose = const CalibratedTokenizer.withRatio(4).count(_prose);
      final tight = const CalibratedTokenizer.withRatio(2).count(_prose);
      expect(tight, greaterThan(loose));
    });

    test('never counts fewer tokens than there are words', () {
      // No tokenizer merges across whitespace, so a word is at least one token.
      // A generous ratio must not be allowed to talk the estimate below that
      // floor — this is the guard that keeps short-word text from being
      // under-counted, which §8 makes a defect rather than an inaccuracy.
      const manyShortWords = 'a b c d e f g h i j k l m n o p q r s t u v w x';
      final words = manyShortWords.split(' ').length;
      expect(
        const CalibratedTokenizer.withRatio(20).count(manyShortWords),
        greaterThanOrEqualTo(words),
      );
    });
  });

  group('calibration', () {
    test('measures the ratio from the engine and errs towards over-counting',
        () async {
      // A vocabulary twice as dense as the uncalibrated guess.
      final tokenizer = await CalibratedTokenizer.calibrate(
        countExact: (text) async => (text.length / 2).ceil(),
        samples: const [_prose],
      );

      // Measured at 2.0 chars/token, then shaded down by the margin — so the
      // stored ratio is *below* what was measured, never above it.
      expect(tokenizer.charsPerToken, lessThan(2.0));
      expect(tokenizer.charsPerToken, greaterThan(1.5));

      // And the estimate it produces is at least what the engine actually says,
      // which is the property the budget depends on.
      final exact = (_prose.length / 2).ceil();
      expect(tokenizer.count(_prose), greaterThanOrEqualTo(exact));
    });

    test('takes the worst sample, not the average', () {
      // A conversation contains the awkward text as well as the easy text, and
      // the budget has to survive the awkward text. Averaging would let one
      // efficiently-tokenized sample license an under-count on everything else.
      return expectLater(
        CalibratedTokenizer.calibrate(
          countExact: (text) async =>
              text.startsWith('DENSE') ? text.length : (text.length / 5).ceil(),
          samples: ['DENSE $_prose', _prose],
        ).then((t) => t.charsPerToken),
        completion(lessThan(1.5)),
      );
    });

    test('never lands above the uncalibrated guess', () async {
      // A model whose vocabulary is unusually efficient on our samples must not
      // drag the estimate up into under-counting ordinary prose.
      final tokenizer = await CalibratedTokenizer.calibrate(
        countExact: (text) async => 1,
        samples: const [_prose],
      );
      expect(
        tokenizer.charsPerToken,
        lessThanOrEqualTo(const CalibratedTokenizer.uncalibrated().charsPerToken),
      );
    });

    test('falls back when the engine tokenizer throws', () async {
      // Calibration refines an estimate that is already safe. It must never be
      // the reason a model refuses to load.
      final tokenizer = await CalibratedTokenizer.calibrate(
        countExact: (_) async => throw StateError('no vocabulary loaded'),
        samples: const [_prose],
      );
      expect(
        tokenizer.charsPerToken,
        const CalibratedTokenizer.uncalibrated().charsPerToken,
      );
    });

    test('falls back when there is nothing long enough to measure', () async {
      // Short strings say more about the vocabulary's edges than its prose.
      final tokenizer = await CalibratedTokenizer.calibrate(
        countExact: (text) async => text.length,
        samples: const ['hello', 'hi'],
      );
      expect(
        tokenizer.charsPerToken,
        const CalibratedTokenizer.uncalibrated().charsPerToken,
      );
    });
  });
}
