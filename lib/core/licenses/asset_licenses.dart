import 'package:flutter/foundation.dart'
    show LicenseEntry, LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/services.dart' show rootBundle;

import '../../llm/model_registry.dart';
import '../di/llm_providers.dart' show modelsManifestAsset;

/// The licences of everything LEV bundles that is **not** a pub package.
///
/// `showLicensePage` gathers pub packages by itself, out of the `NOTICES` file
/// the tool chain generates. It knows nothing about assets — and the three
/// obligations that actually travel with a LEV build are all assets: the two
/// bundled fonts, the SQLCipher binary, and the model's weights. Without this
/// registration the licence page would list forty packages nobody has an
/// obligation about and omit the four that carry one.
///
/// This matters more here than it would elsewhere. LEV is distributed by file
/// transfer rather than through a store (technical-decisions #2), so there is
/// no store listing to carry the notices instead. The licence page inside the
/// product is the only place they can appear.
///
/// **Loading is lazy.** [register] hands `LicenseRegistry` a function returning
/// a stream; nothing is read until someone opens the licence page. Calling it
/// costs a closure, which is why it can sit in `main()` before `runApp`.
abstract final class LevAssetLicenses {
  static const String directory = 'assets/licenses';

  /// The bundled assets whose licences do not arrive with a pub package.
  ///
  /// The model is deliberately **not** here: its licence file is named by the
  /// models manifest, because a second model arrives with a licence of its own
  /// and §5.3 makes adding one a manifest entry rather than a code change.
  static const Map<String, String> fixed = {
    // The interface face, all five weights (#26).
    'IBM Plex Sans Hebrew': '$directory/ibm-plex-ofl.txt',
    // The logo's wordmark, subset to A–Z (#28).
    'Outfit': '$directory/outfit-ofl.txt',
    // Whole-database encryption, linked as a native library (#13).
    'SQLCipher': '$directory/sqlcipher.txt',
  };

  /// Adds the asset licences to the registry. Call **once**, from `main()`,
  /// before `runApp`.
  static void register() => LicenseRegistry.addLicense(entries);

  /// The entries themselves.
  ///
  /// Public so a test can drain it without touching the global registry —
  /// `LicenseRegistry` has no way to remove what has been added, so a test that
  /// went through [register] would leak into every test after it.
  static Stream<LicenseEntry> entries() async* {
    for (final entry in fixed.entries) {
      yield LicenseEntryWithLineBreaks(
        [entry.key],
        await rootBundle.loadString(entry.value),
      );
    }

    // The model's licence is named by the manifest. A failure here is
    // swallowed: the licence page is reached from Settings, and a manifest that
    // cannot be read is already a chat that cannot start — reported where that
    // actually happens, not by crashing a page someone opened to read a notice.
    // The fixed entries above have already been yielded either way.
    try {
      final registry = ModelRegistry.parse(
        await rootBundle.loadString(modelsManifestAsset),
      );
      for (final model in registry.models) {
        final asset = model.licenseAsset;
        if (asset == null) continue;
        yield LicenseEntryWithLineBreaks(
          [model.attribution ?? model.id],
          await rootBundle.loadString(asset),
        );
      }
    } on Object {
      return;
    }
  }
}
