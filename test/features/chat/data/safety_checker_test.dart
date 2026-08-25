import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:lev/core/di/prompt_providers.dart';
import 'package:lev/features/chat/data/asset_safety_checker.dart';

import 'safety_corpus.dart';

/// The deterministic safety layer (technical-spec §5.2.4).
///
/// §5.2.4 requires this corpus to pass "regardless of which engine is
/// registered". No engine appears anywhere in this file, which is the strongest
/// form of that guarantee: there is nothing here for an engine to affect.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The real asset files, loaded once. Both locales are read up front because
  // `rootBundle` caches the future it returns and a cached asset future does not
  // resolve again inside a later test's zone.
  late AssetSafetyChecker english;
  late AssetSafetyChecker hebrew;

  setUpAll(() async {
    english = AssetSafetyChecker.parse(
      await rootBundle.loadString(safetyPatternsAsset('en')),
    );
    hebrew = AssetSafetyChecker.parse(
      await rootBundle.loadString(safetyPatternsAsset('he')),
    );
  });

  group('English corpus', () {
    test('every case behaves as the corpus says', () {
      final wrong = <String>[];
      for (final testCase in englishCorpus) {
        final matched = english.evaluate(testCase.text).matched;
        if (matched != testCase.expectMatch) {
          wrong.add('$testCase${testCase.why.isEmpty ? '' : ' — ${testCase.why}'}');
        }
      }

      // Reported together rather than one failure at a time: tuning these
      // patterns is a balancing act, and seeing only the first regression hides
      // what the fix on one side did to the other.
      expect(wrong, isEmpty, reason: 'safety corpus regressions:\n${wrong.join('\n')}');
    });

    test('a match carries the support message and the pattern that fired', () {
      final verdict = english.evaluate('I want to die');

      expect(verdict.matched, isTrue);
      expect(verdict.supportMessage, isNotEmpty);
      expect(verdict.patternId, isNotNull);
    });

    test('a clear message carries no notice at all', () {
      final verdict = english.evaluate('I had a hard day');

      expect(verdict.matched, isFalse);
      expect(verdict.supportMessage, isNull);
    });

    test('the support message points at a person, not at the app', () {
      final message = english.supportMessage.toLowerCase();

      // §5.2.4 and the product-level risk in §10: LEV must never present itself
      // as crisis support.
      expect(
        message,
        anyOf(contains('crisis'), contains('emergency'), contains('trust')),
      );
    });
  });

  group('Hebrew corpus', () {
    test('every case behaves as the corpus says', () {
      final wrong = <String>[];
      for (final testCase in hebrewCorpus) {
        final matched = hebrew.evaluate(testCase.text).matched;
        if (matched != testCase.expectMatch) {
          wrong.add('$testCase${testCase.why.isEmpty ? '' : ' — ${testCase.why}'}');
        }
      }

      expect(wrong, isEmpty, reason: 'safety corpus regressions:\n${wrong.join('\n')}');
    });

    test('the notice is in Hebrew, not the English one', () {
      // A person who wrote in Hebrew and is in distress should not be answered
      // in a language they may not read (#11).
      expect(hebrew.supportMessage, matches(RegExp(r'[֐-׿]')));
    });
  });

  group('parsing', () {
    test('rejects a list with no support message', () {
      expect(
        () => AssetSafetyChecker.parse(
          '{"patterns":[{"id":"a","pattern":"x"}]}',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects an empty pattern list', () {
      expect(
        () => AssetSafetyChecker.parse('{"supportMessage":"m","patterns":[]}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects an entry missing its id or pattern', () {
      expect(
        () => AssetSafetyChecker.parse(
          '{"supportMessage":"m","patterns":[{"pattern":"x"}]}',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  test('the fallback checker never matches', () {
    // Registered only for a language with no pattern file. Failing open is
    // right here: the notice is supplementary, so a missing list must not take
    // the chat down with it.
    const fallback = NeverMatchingSafetyChecker();

    for (final testCase in englishCorpus) {
      expect(fallback.evaluate(testCase.text).matched, isFalse);
    }
  });
}
