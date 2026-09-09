import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/licenses/asset_licenses.dart';

void main() {
  // Once, before the tree exists. The fonts, SQLCipher and the model's weights
  // are **assets**, so `showLicensePage` — which collects pub packages and
  // nothing else — would never mention them, and LEV ships by file transfer
  // rather than through a store, so there is no listing anywhere else to carry
  // the notices. Nothing is read here: `addLicense` takes a stream that is only
  // drained when the licence page is opened.
  LevAssetLicenses.register();

  runApp(const ProviderScope(child: LevApp()));
}
