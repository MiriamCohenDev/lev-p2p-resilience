import 'dart:io';

import 'package:flutter/foundation.dart' show LicenseEntry;
import 'package:flutter_test/flutter_test.dart';
import 'package:lev/core/licenses/asset_licenses.dart';

/// The check that proves the legal obligation is actually met.
///
/// `showLicensePage` collects **pub packages** — it reads the `NOTICES` file the
/// tool chain generates and knows nothing about assets. The three things LEV
/// bundles that carry a real obligation are all assets: the fonts, the SQLCipher
/// binary, and the model's weights. Registering them is easy to do and easy to
/// half-do, and a half-done registration looks exactly like a working one until
/// somebody opens the page. So this test drains the stream and insists the text
/// is there.
///
/// It reads through `rootBundle` on purpose, rather than off the disk as
/// `support_resources_test.dart` does. Reading the files would prove they were
/// committed; reading the bundle proves they were **declared in `pubspec.yaml`**,
/// which is the half that silently fails.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<LicenseEntry> entries;

  setUpAll(() async {
    entries = await LevAssetLicenses.entries().toList();
  });

  /// The paragraphs of the entry whose package list contains [needle], joined.
  String textOf(String needle) {
    final entry = entries.firstWhere(
      (e) => e.packages.any((p) => p.contains(needle)),
      orElse: () => throw TestFailure(
        'no licence entry mentions "$needle"; got '
        '${entries.map((e) => e.packages).toList()}',
      ),
    );
    return entry.paragraphs.map((p) => p.text).join('\n');
  }

  group('the bundled fonts', () {
    test('IBM Plex Sans Hebrew ships its OFL', () {
      final text = textOf('IBM Plex');
      expect(text, contains('SIL OPEN FONT LICENSE'));
      expect(text, contains('IBM Corp'));
    });

    test('the wordmark font ships its OFL too', () {
      // Easily forgotten, because it is 3.3 KB and renders three letters — and
      // it was in fact missing from the repository before this section existed.
      final text = textOf('Outfit');
      expect(text, contains('SIL OPEN FONT LICENSE'));
      expect(text, contains('Outfit'));
    });
  });

  test('SQLCipher ships its licence', () {
    final text = textOf('SQLCipher');
    expect(text, contains('Zetetic'));
    expect(text, contains('Redistribution and use'));
  });

  test('the model ships its licence, named by the manifest', () {
    // Not looked up by a hardcoded name: the entry is titled with the
    // manifest's own `attribution`, so a second model with a different licence
    // is a manifest entry rather than a change here (§5.3).
    final text = textOf('Qwen');
    expect(text, contains('Apache License'));
    expect(text, contains('Alibaba'));
  });

  test('every entry carries real text, not an empty shell', () {
    expect(entries, isNotEmpty);
    for (final entry in entries) {
      expect(entry.packages, isNotEmpty);
      expect(
        entry.paragraphs.map((p) => p.text).join().trim(),
        isNotEmpty,
        reason: '${entry.packages} has an empty licence',
      );
    }
  });

  test('the registration is actually made, and made once', () {
    // The stream above proves the entries are correct; nothing in a test can
    // prove the running app ever asks for them, because `LicenseRegistry` has
    // no way to inspect or undo what has been added. What can be checked is
    // that `main()` still calls it — the one line whose deletion would take the
    // whole page's asset half with it, silently.
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains('LevAssetLicenses.register()'));
    expect(
      'LevAssetLicenses.register()'.allMatches(main),
      hasLength(1),
      reason: 'registering twice lists every asset licence twice',
    );
  });
}
