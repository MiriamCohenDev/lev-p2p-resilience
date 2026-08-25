import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'crypto_errors.dart';
import 'secure_key_store.dart';

/// [SecureKeyStore] backed by the OS secure store: Android Keystore, Keychain
/// on Apple platforms, `wincred` on Windows, libsecret on Linux.
///
/// Its whole job beyond delegation is translating platform failures into this
/// module's typed errors, so nothing above it ever sees a raw
/// [PlatformException] — and so a failure can never be mistaken for "absent".
class FlutterSecureKeyStore implements SecureKeyStore {
  FlutterSecureKeyStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              // Default ciphers as of plugin v10+: RSA-OAEP wrapping an AES-GCM
              // storage key. Not the biometric variant — gating the KEK behind
              // biometrics belongs with PIN mode, which is not built yet.
              aOptions: AndroidOptions(),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) =>
      _guard('read', key, () => _storage.read(key: key));

  @override
  Future<void> write(String key, String value) =>
      _guard('write', key, () => _storage.write(key: key, value: value));

  @override
  Future<void> delete(String key) =>
      _guard('delete', key, () => _storage.delete(key: key));

  /// Every failure out of the plugin becomes [KeyStoreUnavailable]: at this
  /// layer we only know the store could not serve the request, not why.
  /// Deciding a *returned* value is unusable is the caller's job
  /// ([KeyStoreCorrupted]).
  Future<T> _guard<T>(
    String operation,
    String key,
    Future<T> Function() body,
  ) async {
    try {
      return await body();
    } on PlatformException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        KeyStoreUnavailable(
          'secure storage $operation failed for "$key"',
          cause: error,
        ),
        stackTrace,
      );
    } on MissingPluginException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        KeyStoreUnavailable(
          'secure storage is not available on this platform ($operation "$key")',
          cause: error,
        ),
        stackTrace,
      );
    }
  }
}
