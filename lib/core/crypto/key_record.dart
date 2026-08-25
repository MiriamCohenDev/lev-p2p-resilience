import 'dart:convert';

import 'crypto_errors.dart';
import 'kek_source.dart';

/// Everything about the DEK except the KEK that opens it, in one stored value.
///
/// Holding the wrapped DEK *inside* this record is deliberate, and it is what
/// makes switching between default mode and PIN mode crash-safe. Re-wrapping
/// becomes: derive the new KEK → wrap the same DEK → **write this record once**
/// → drop the KEK the old mode used. That single write is the commit point.
/// Interrupt the app before it and the old record and old KEK are both intact;
/// interrupt after it and the new record is authoritative, leaving at most an
/// unused KEK entry behind for `KeyManager.sweepIncompleteRewrap` to remove.
/// There is no ordering in which no valid wrapping exists, and the database is
/// never re-encrypted — the DEK inside is the same bytes either way.
///
/// [kdf] and [salt] stay `null` until PIN mode exists; the fields are here now
/// so adding it is a write, not a migration.
class KeyRecord {
  const KeyRecord({
    required this.wrapping,
    required this.wrappedDek,
    required this.createdAt,
    this.kdf,
    this.salt,
  });

  static const int _version = 1;

  /// How the KEK for [wrappedDek] is obtained.
  final KeyWrappingMode wrapping;

  /// The DEK, encrypted under that KEK. See `key_envelope.dart`.
  final String wrappedDek;

  /// Key-derivation function name, once [wrapping] is [KeyWrappingMode.pin].
  final String? kdf;

  /// Base64 salt for [kdf]. Not secret.
  final String? salt;

  final DateTime createdAt;

  String encode() => jsonEncode({
        'v': _version,
        'wrapping': wrapping.wireName,
        'wrappedDek': wrappedDek,
        'kdf': kdf,
        'salt': salt,
        'createdAt': createdAt.toUtc().toIso8601String(),
      });

  /// Throws [KeyStoreCorrupted] rather than returning null for anything
  /// unreadable — a record we cannot parse is not an absent record.
  static KeyRecord decode(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        KeyStoreCorrupted('key record is not valid JSON', cause: error),
        stackTrace,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const KeyStoreCorrupted('key record is not a JSON object');
    }

    final version = decoded['v'];
    if (version != _version) {
      throw KeyStoreCorrupted(
        'unknown key record version $version, expected $_version',
      );
    }

    final wrappingName = decoded['wrapping'];
    if (wrappingName is! String) {
      throw const KeyStoreCorrupted('key record has no wrapping mode');
    }
    final wrapping = KeyWrappingMode.fromWireName(wrappingName);
    if (wrapping == null) {
      throw KeyStoreCorrupted('unknown wrapping mode "$wrappingName"');
    }

    final wrappedDek = decoded['wrappedDek'];
    if (wrappedDek is! String || wrappedDek.isEmpty) {
      throw const KeyStoreCorrupted('key record holds no wrapped DEK');
    }

    final createdAt = DateTime.tryParse(decoded['createdAt'] as String? ?? '');
    if (createdAt == null) {
      throw const KeyStoreCorrupted('key record has no valid createdAt');
    }

    return KeyRecord(
      wrapping: wrapping,
      wrappedDek: wrappedDek,
      createdAt: createdAt,
      kdf: decoded['kdf'] as String?,
      salt: decoded['salt'] as String?,
    );
  }
}
