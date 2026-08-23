import 'dart:typed_data';

/// How the KEK is obtained. Recorded in the key record so a launch knows what
/// to ask for before it asks.
enum KeyWrappingMode {
  /// Default: the KEK is random and lives in the OS secure store. No prompt.
  secureStorage('secure'),

  /// Not implemented. The KEK is derived from the user's PIN via Argon2 and is
  /// never stored. Listed here because the record format must be able to name
  /// it from day one — see `key_record.dart`.
  pin('pin');

  const KeyWrappingMode(this.wireName);

  /// Stable string used in the persisted record. Never the enum name, so
  /// renaming a constant cannot change what is on disk.
  final String wireName;

  static KeyWrappingMode? fromWireName(String name) {
    for (final mode in KeyWrappingMode.values) {
      if (mode.wireName == name) return mode;
    }
    return null;
  }
}

/// Where the KEK comes from.
///
/// This is the entire seam for the future PIN mode: an Argon2-backed source
/// implements the same two methods, deriving from a PIN instead of reading the
/// OS store, and nothing above this interface changes.
abstract class KekSource {
  KeyWrappingMode get mode;

  /// The existing KEK, or `null` if there is cleanly none yet.
  ///
  /// Throws — never returns `null` — when the KEK could not be read. A future
  /// Argon2 source returns `null` from this only if no PIN has been set.
  Future<Uint8List?> loadKek();

  /// Produces the KEK for a brand-new installation, persisting it if this
  /// source is one that stores.
  Future<Uint8List> createKek();
}
