/// Names under which key material is stored.
///
/// Versioned from the start: changing an encoding later means writing a `.v2`
/// key beside the old one, not reinterpreting bytes in place.
class KeyStoreKeys {
  const KeyStoreKeys._();

  /// The raw KEK. Present only while the KEK lives in the OS secure store —
  /// in a future PIN mode it is derived and this entry is absent.
  static const String kek = 'lev.kek.v1';

  /// The whole key record, wrapped DEK included. See `key_record.dart`.
  static const String record = 'lev.keystate.v1';
}

/// The port this module talks to instead of `flutter_secure_storage` directly.
///
/// Two reasons it exists: unit tests run on the Dart VM where platform channels
/// are absent, and the contract below is stricter than the plugin's.
///
/// **Contract — absent is not failure.** [read] returns `null` only when the
/// store answered cleanly that the key is not there. Anything that went wrong
/// throws a [KeyManagementException]. Implementations must never collapse an
/// error into `null`; the whole first-run detection rests on that difference.
abstract class SecureKeyStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}
