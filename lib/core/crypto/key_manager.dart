import 'dart:async';
import 'dart:typed_data';

import 'crypto_errors.dart';
import 'kek_source.dart';
import 'key_envelope.dart';
import 'key_material.dart';
import 'key_record.dart';
import 'secure_key_store.dart';

/// Answers one question: what is this device's DEK — the key SQLCipher opens
/// the database with (technical-spec §7.3, technical-decisions #5)?
///
/// Knows nothing about Drift or SQL. Hand [toSqlCipherKey] the bytes it returns
/// and the storage layer has what it needs.
abstract class KeyManager {
  /// The DEK, provisioning one on a genuinely first run.
  ///
  /// Throws a [KeyManagementException] in every other unhappy case. It never
  /// returns a *new* DEK for an installation that already had one — see
  /// [DefaultKeyManager] for why that rule is the point of this class.
  Future<Uint8List> obtainDek();

  /// How the KEK is currently obtained. Before anything is provisioned, this is
  /// the mode a first run would use.
  Future<KeyWrappingMode> currentMode();

  /// Removes key material the current wrapping mode does not use — the debris
  /// an interrupted mode switch can leave. Safe to call on every launch, and a
  /// no-op until PIN mode exists.
  Future<void> sweepIncompleteRewrap();

  /// Wipes the cached DEK. The next [obtainDek] re-reads and re-unwraps it.
  void dispose();
}

class DefaultKeyManager implements KeyManager {
  DefaultKeyManager({
    required this._store,
    required this._kekSource,
    SecureRandomSource? random,
    DateTime Function()? clock,
  })  : _random = random ?? DartSecureRandom(),
        _clock = clock ?? DateTime.now;

  final SecureKeyStore _store;
  final KekSource _kekSource;
  final SecureRandomSource _random;
  final DateTime Function() _clock;

  Uint8List? _dek;
  Future<Uint8List>? _pending;

  @override
  Future<Uint8List> obtainDek() {
    final cached = _dek;
    if (cached != null) return Future.value(Uint8List.fromList(cached));

    // Single-flight: two callers racing on startup must not each conclude
    // "nothing stored yet" and provision a DEK, which would leave the second
    // one's database key overwriting the first one's.
    final pending = _pending;
    if (pending != null) return pending;

    final future = _obtainDek();
    _pending = future;
    // Drop the in-flight future once it settles: on success the DEK is cached
    // above, and on failure a caller should be able to retry a store that was
    // only transiently unavailable. Handled through a derived future so the
    // failure is not reported twice.
    unawaited(
      future.then<void>(
        (_) => _pending = null,
        onError: (Object error, StackTrace stackTrace) => _pending = null,
      ),
    );
    return future;
  }

  Future<Uint8List> _obtainDek() async {
    // Any failure below propagates as an exception. Nothing here treats a
    // failed read as an absent key: provisioning over an existing encrypted
    // database would destroy it silently, and there is no server to recover
    // from.
    final kek = await _kekSource.loadKek();
    final rawRecord = await _store.read(KeyStoreKeys.record);

    if (kek == null && rawRecord == null) {
      return _provision();
    }

    if (kek == null) {
      throw const KeyMaterialMissing(
        MissingKeyMaterial.kek,
        'a wrapped DEK is stored but its KEK is gone — the database on disk '
        'can no longer be opened by anyone. Refusing to provision a new key '
        'over it.',
      );
    }
    if (rawRecord == null) {
      wipe(kek);
      throw const KeyMaterialMissing(
        MissingKeyMaterial.wrappedDek,
        'a KEK is stored but the key record is gone. If no database file '
        'exists this installation can be reset; if one does, its contents are '
        'unrecoverable.',
      );
    }

    final record = KeyRecord.decode(rawRecord);
    final dek = await KeyEnvelope.unwrap(record.wrappedDek, kek);
    wipe(kek);
    _dek = dek;
    return Uint8List.fromList(dek);
  }

  /// First run: mint the DEK, wrap it, and commit the record.
  ///
  /// Order matters. The KEK is written first, so an interruption before the
  /// record lands leaves the loud [MissingKeyMaterial.wrappedDek] state above
  /// rather than a silent half-installation.
  Future<Uint8List> _provision() async {
    final dek = _random.nextBytes(keyLengthBytes);
    final kek = await _kekSource.createKek();
    final wrappedDek = await KeyEnvelope.wrap(dek, kek);
    wipe(kek);

    await _store.write(
      KeyStoreKeys.record,
      KeyRecord(
        wrapping: _kekSource.mode,
        wrappedDek: wrappedDek,
        createdAt: _clock(),
      ).encode(),
    );

    _dek = dek;
    return Uint8List.fromList(dek);
  }

  @override
  Future<KeyWrappingMode> currentMode() async {
    final rawRecord = await _store.read(KeyStoreKeys.record);
    if (rawRecord == null) return _kekSource.mode;
    return KeyRecord.decode(rawRecord).wrapping;
  }

  @override
  Future<void> sweepIncompleteRewrap() async {
    final rawRecord = await _store.read(KeyStoreKeys.record);
    if (rawRecord == null) return;

    // The record is authoritative about which KEK is live. A stored KEK that
    // the committed mode does not use is left over from a switch that was
    // interrupted after its commit, and is safe — necessary, even — to drop.
    if (KeyRecord.decode(rawRecord).wrapping != KeyWrappingMode.secureStorage) {
      await _store.delete(KeyStoreKeys.kek);
    }
  }

  @override
  void dispose() {
    final dek = _dek;
    if (dek != null) wipe(dek);
    _dek = null;
  }
}
