import 'package:lev/core/crypto/crypto_errors.dart';
import 'package:lev/core/crypto/secure_key_store.dart';

/// [SecureKeyStore] backed by a map, so the key-management tests run on the
/// Dart VM with no platform channels.
///
/// [failOnRead] / [failOnWrite] reproduce what the real store does when the OS
/// cannot serve it — a locked keyring, a missing Secret Service on Linux — and
/// they throw rather than return `null`, because that difference is exactly
/// what the module under test keys off.
class InMemoryKeyStore implements SecureKeyStore {
  InMemoryKeyStore([Map<String, String>? initial])
      : values = {...?initial};

  final Map<String, String> values;

  bool failOnRead = false;
  bool failOnWrite = false;

  /// Every key ever written, in order — lets a test assert that a failed run
  /// wrote nothing at all.
  final List<String> writes = [];

  @override
  Future<String?> read(String key) async {
    if (failOnRead) {
      throw const KeyStoreUnavailable('read failed (test)');
    }
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failOnWrite) {
      throw const KeyStoreUnavailable('write failed (test)');
    }
    writes.add(key);
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
