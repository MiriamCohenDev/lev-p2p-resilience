// Runs the licence page on a real device, out of a real build:
//
//   flutter test integration_test/about_licenses_test.dart -d windows
//   flutter test integration_test/about_licenses_test.dart -d emulator-5554
//
// `test/core/licenses/` proves the same thing against the *test* asset bundle,
// which is where the check belongs day to day. This file proves the half a host
// test cannot: that `assets/licenses/` is actually packaged into the shipped
// artifact, and that our four asset entries sit in the same page as the pub
// packages Flutter collects from the generated `NOTICES` — which only exists in
// a real build.
//
// That distinction is the whole reason the section was built. LEV ships by file
// transfer rather than through a store (technical-decisions #2), so this page is
// the only place the font, the model and SQLCipher licences can appear. A build
// that dropped the asset declaration would look completely healthy everywhere
// else.
import 'package:flutter/foundation.dart' show LicenseRegistry;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lev/core/licenses/asset_licenses.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the shipped licence page carries the bundled assets',
      (tester) async {
    // Exactly what `main()` does, and the only thing it does before `runApp`.
    LevAssetLicenses.register();

    await tester.pumpWidget(
      const MaterialApp(home: LicensePage(applicationName: 'LEV')),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    for (final name in const [
      'IBM Plex Sans Hebrew',
      'Outfit',
      'SQLCipher',
    ]) {
      expect(find.text(name), findsWidgets, reason: '"$name" is missing');
    }
    expect(find.textContaining('Qwen2.5-0.5B-Instruct'), findsWidgets);

    // Registering ours **adds to** Flutter's own collector rather than
    // replacing it, so the pub packages are still listed beside them.
    //
    // Asserted through the bundle rather than through `LicenseRegistry`, and
    // for a reason worth writing down: Flutter's collector reads `NOTICES.Z`
    // and decompresses it on a background isolate, which never completes under
    // a test binding's fake async. Draining the registry here therefore returns
    // *only* our four entries — in the test, never in the running app. What can
    // be checked is that the file the collector reads was actually packaged.
    expect(
      (await rootBundle.load('NOTICES.Z')).lengthInBytes,
      greaterThan(0),
      reason: 'the generated pub-package notices are missing from the build',
    );

    // And these are ours, in the same build, from `assets/licenses/`.
    final packages = <String>{};
    await LicenseRegistry.licenses.forEach((e) => packages.addAll(e.packages));
    expect(packages, contains('SQLCipher'));
    expect(packages, contains('IBM Plex Sans Hebrew'));
  });
}
