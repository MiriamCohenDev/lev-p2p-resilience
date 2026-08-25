import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:lev/core/di/prompt_providers.dart';
import 'package:lev/features/chat/data/system_prompt.dart';

/// The versioned system prompt (technical-spec §5.2.1).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String source;

  setUpAll(() async {
    source = await rootBundle.loadString(systemPromptAsset);
  });

  group('the shipped prompt', () {
    test('parses and declares a version', () {
      final prompt = SystemPrompt.parse(source);

      // §5.2.1 records the version on every conversation so a change in
      // behaviour is traceable to the prompt that caused it.
      expect(prompt.version, isNotEmpty);
      expect(prompt.text, isNotEmpty);
      expect(prompt.text, isNot(contains('---')),
          reason: 'front matter must not leak into the prompt');
    });

    test('states the limits §5.2.1 requires it to state', () {
      final text = SystemPrompt.parse(source).text.toLowerCase();

      // Not a style check — these are the product's hard limits (§5.2.1, and
      // the wellbeing risk in §10), and a rewrite that quietly drops one is
      // exactly what this catches.
      expect(text, contains('diagnos'));
      expect(text, contains('medical'));
      expect(text, contains('legal'));
      expect(text, anyOf(contains('crisis'), contains('emergency')));
    });

    test('does not promise memory or capabilities LEV does not have', () {
      final text = SystemPrompt.parse(source).text.toLowerCase();

      // v1 has no network by NFR (§8) and no cross-conversation memory.
      expect(text, contains('never claim to remember'));
    });
  });

  group('parsing', () {
    test('reads the version out of the front matter', () {
      final prompt = SystemPrompt.parse('---\nversion: 2.1.0\n---\nBe kind.');

      expect(prompt.version, '2.1.0');
      expect(prompt.text, 'Be kind.');
    });

    test('handles CRLF line endings', () {
      // The repository is checked out with CRLF on Windows, which is where this
      // is developed — a parser that only accepts LF would fail on the machine
      // it was written on.
      final prompt =
          SystemPrompt.parse('---\r\nversion: 1.0.0\r\n---\r\nBe kind.\r\n');

      expect(prompt.version, '1.0.0');
      expect(prompt.text, 'Be kind.');
    });

    test('refuses a prompt with no front matter', () {
      expect(
        () => SystemPrompt.parse('Be kind.'),
        throwsA(isA<FormatException>()),
      );
    });

    test('refuses a prompt that declares no version', () {
      expect(
        () => SystemPrompt.parse('---\nauthor: someone\n---\nBe kind.'),
        throwsA(isA<FormatException>()),
      );
    });

    test('refuses an empty body', () {
      expect(
        () => SystemPrompt.parse('---\nversion: 1.0.0\n---\n   '),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
