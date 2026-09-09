import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lev/core/licenses/asset_licenses.dart';

/// Flutter's own `LicensePage`, driven against the real `LicenseRegistry`.
///
/// `asset_licenses_test.dart` proves the entries are correct. This proves they
/// come out the other end: registration and rendering are two different things,
/// and the page has its own idea of how a licence is grouped and displayed.
/// Together they are the check the task asks for — that the page really lists
/// the font, SQLCipher and the model, and not only the pub packages it collects
/// on its own.
///
/// **A file of its own, deliberately.** `LicenseRegistry` is global and has no
/// way to remove what has been added, so registering inside a shared file would
/// leak into every test after it. `flutter test` gives each file its own
/// isolate, which is what makes this safe.
void main() {
  testWidgets('the licence page lists the bundled assets, not only pub packages',
      (tester) async {
    LevAssetLicenses.register();

    await tester.pumpWidget(
      const MaterialApp(home: LicensePage(applicationName: 'LEV')),
    );
    // The page reads the registry asynchronously and builds its list as entries
    // arrive; `pumpAndSettle` alone lands before the stream is drained.
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    // The four obligations that travel with a LEV build and that
    // `showLicensePage` cannot discover by itself: they are assets, and it
    // collects packages.
    for (final name in ['IBM Plex Sans Hebrew', 'Outfit', 'SQLCipher']) {
      expect(
        find.text(name),
        findsWidgets,
        reason: '"$name" is missing from the licence page',
      );
    }

    // The model is listed under the manifest's own attribution string, so a
    // different model is a manifest change rather than a code change.
    expect(
      find.textContaining('Qwen2.5-0.5B-Instruct'),
      findsWidgets,
      reason: "the model's attribution is missing from the licence page",
    );
  });
}
