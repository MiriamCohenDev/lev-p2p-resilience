import 'dart:typed_data';

import 'package:lev/core/crypto/crypto_errors.dart';
import 'package:lev/core/crypto/kek_source.dart';
import 'package:lev/core/crypto/key_manager.dart';
import 'package:lev/core/crypto/key_material.dart';

/// A [KeyManager] that either hands out a known DEK or throws a chosen
/// [KeyManagementException], so the storage layer's reaction to each failure can
/// be tested without a device.
///
/// Written by hand rather than mocked, matching `test/core/crypto/`.
class FakeKeyManager implements KeyManager {
  FakeKeyManager.withDek(Uint8List dek)
      : _dek = dek,
        _failure = null;

  FakeKeyManager.failing(KeyManagementException failure)
      : _dek = null,
        _failure = failure;

  final Uint8List? _dek;
  final KeyManagementException? _failure;

  int obtainCalls = 0;

  @override
  Future<Uint8List> obtainDek() async {
    obtainCalls++;
    final failure = _failure;
    if (failure != null) throw failure;
    // A copy per call, like DefaultKeyManager — the caller is free to wipe it.
    return Uint8List.fromList(_dek!);
  }

  @override
  Future<KeyWrappingMode> currentMode() async => KeyWrappingMode.secureStorage;

  @override
  Future<void> sweepIncompleteRewrap() async {}

  @override
  void dispose() {}
}

/// A deterministic 32-byte key. [seed] varies it so a test can produce a second,
/// different key.
Uint8List fakeDek(int seed) =>
    Uint8List.fromList(List.generate(keyLengthBytes, (i) => (i + seed) % 256));
