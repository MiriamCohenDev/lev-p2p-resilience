import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lev/core/support/support_resources.dart';

/// The shipped support resources (technical-decisions #24).
///
/// Read from disk rather than through `rootBundle`: the bundle caches the future
/// it returns, and a cached asset future does not resolve again inside a later
/// test's `fake_async` zone. What matters here is the content of the files, and
/// the files are what is read.
void main() {
  final locales = ['he', 'en'];

  Map<String, dynamic> raw(String locale) => jsonDecode(
        File('assets/support/$locale.json').readAsStringSync(),
      ) as Map<String, dynamic>;

  for (final locale in locales) {
    group('assets/support/$locale.json', () {
      test('parses and carries every field the card needs', () {
        final resource = LevSupportResource.fromJson(raw(locale));

        expect(resource.title, isNotEmpty);
        expect(resource.body, isNotEmpty);
        expect(resource.callLabel, isNotEmpty);
        expect(resource.phone, isNotEmpty);
        expect(resource.serviceName, isNotEmpty);
      });

      test('the number is dialable — digits, and nothing else', () {
        // The one action on the card is `tel:`. A number carrying spaces,
        // dashes or a country name would produce a URI the dialler refuses,
        // which is a dead button at the worst possible moment.
        expect(
          LevSupportResource.fromJson(raw(locale)).phone,
          matches(RegExp(r'^\+?[0-9]+$')),
        );
      });

      test('it does not promise confidentiality on somebody else\'s behalf',
          () {
        final body = LevSupportResource.fromJson(raw(locale)).body;

        // That varies between services and between circumstances. There is one
        // fact that can be stood behind — a person is there, around the clock —
        // and the text may claim only that.
        for (final forbidden in ['אנונימ', 'חסוי', 'anonymous', 'confidential']) {
          expect(
            body.toLowerCase(),
            isNot(contains(forbidden.toLowerCase())),
            reason: 'the support message must not promise "$forbidden"',
          );
        }
      });

      test('it has been reviewed, and the date is a real one', () {
        final reviewedOn =
            LevSupportResource.fromJson(raw(locale)).reviewedOn;
        final parsed = DateTime.tryParse(reviewedOn);

        // A number that has gone stale is worse than a message that never
        // appeared. This cannot check the number against the world, but it can
        // insist that somebody wrote down when they last did.
        expect(parsed, isNotNull, reason: 'reviewedOn must be YYYY-MM-DD');
        expect(parsed!.isAfter(DateTime(2026)), isTrue);
      });
    });
  }

  test('every shipped UI language has a support resource', () {
    // A language with a translated interface but no support resource would fall
    // back to Hebrew — a message the reader may not be able to read, at the
    // moment it matters most.
    for (final locale in locales) {
      expect(File('assets/support/$locale.json').existsSync(), isTrue);
    }
  });
}
