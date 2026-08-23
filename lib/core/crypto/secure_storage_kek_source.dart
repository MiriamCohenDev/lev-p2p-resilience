import 'dart:convert';
import 'dart:typed_data';

import 'crypto_errors.dart';
import 'kek_source.dart';
import 'key_material.dart';
import 'secure_key_store.dart';

/// The default KEK source: 32 random bytes held by the OS secure store.
///
/// This is what technical-spec §7.3 calls default mode — the app opens with no
/// prompt because the platform, not the user, holds the key.
class SecureStorageKekSource implements KekSource {
  SecureStorageKekSource(this._store, {SecureRandomSource? random})
      : _random = random ?? DartSecureRandom();

  final SecureKeyStore _store;
  final SecureRandomSource _random;

  @override
  KeyWrappingMode get mode => KeyWrappingMode.secureStorage;

  @override
  Future<Uint8List?> loadKek() async {
    final encoded = await _store.read(KeyStoreKeys.kek);
    if (encoded == null) return null;

    final Uint8List kek;
    try {
      kek = base64Decode(encoded);
    } on FormatException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        KeyStoreCorrupted('stored KEK is not valid base64', cause: error),
        stackTrace,
      );
    }
    if (kek.length != keyLengthBytes) {
      throw KeyStoreCorrupted(
        'stored KEK is ${kek.length} bytes, expected $keyLengthBytes',
      );
    }
    return kek;
  }

  @override
  Future<Uint8List> createKek() async {
    final kek = _random.nextBytes(keyLengthBytes);
    await _store.write(KeyStoreKeys.kek, base64Encode(kek));
    return kek;
  }
}
