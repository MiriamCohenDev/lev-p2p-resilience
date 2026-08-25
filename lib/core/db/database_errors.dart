import '../crypto/crypto_errors.dart';

/// Typed failures raised while opening the encrypted database.
///
/// The storage layer is where technical-decisions #12 left one question
/// deliberately unanswered: a [KeyManagementException] says what happened to the
/// *key*, but only this layer can see whether a *database file* exists — and
/// that is what decides whether a given failure is an inconvenience or
/// permanent data loss. These types carry that judgement to the caller.
///
/// One rule holds across every case below, and it is the reason the hierarchy
/// exists at all: **no database file is ever opened, created, or deleted
/// without a valid DEK, and there is never a fallback to an unencrypted
/// database.** A key failure leaves the disk exactly as it was.
sealed class DatabaseOpenException implements Exception {
  const DatabaseOpenException(this.message, {this.cause});

  final String message;

  /// The [KeyManagementException] underneath, when the failure came from there.
  final Object? cause;

  @override
  String toString() => cause == null
      ? '$runtimeType: $message'
      : '$runtimeType: $message (cause: $cause)';
}

/// The key could not be read right now, but nothing is known to be lost.
///
/// A locked keyring, a missing Secret Service on Linux, an Android Keystore that
/// threw. The same call may well succeed on the next launch, so this is the one
/// failure a caller may reasonably retry — and the one the UI should present as
/// "try again", never as "your data is gone".
class DatabaseKeyUnavailable extends DatabaseOpenException {
  const DatabaseKeyUnavailable(super.message, {super.cause});
}

/// The DEK for this installation cannot be reconstructed.
///
/// [databaseFileExists] is the whole point of this class. With no file on disk
/// there is nothing to lose and the installation can be reset — but resetting is
/// destructive and is *not* done here; it needs the user's explicit consent.
/// With a file on disk, its contents are unrecoverable: there is no server and
/// no backup, so the only correct action is to fail loudly and touch nothing.
class DatabaseKeyLost extends DatabaseOpenException {
  const DatabaseKeyLost(
    super.message, {
    required this.databaseFileExists,
    super.cause,
  });

  /// Whether a database file was already on disk when the failure happened.
  final bool databaseFileExists;

  @override
  String toString() => '${super.toString()} '
      '[databaseFileExists: $databaseFileExists]';
}

/// The opened database is not running SQLCipher.
///
/// Means the `hooks.user_defines.sqlite3.source` setting in `pubspec.yaml` did
/// not take effect and the app is linked against plain SQLite. That build
/// ignores `PRAGMA key` **silently** and would write user data to disk in
/// plaintext, so it is caught at open time and treated as fatal.
class DatabaseNotEncrypted extends DatabaseOpenException {
  const DatabaseNotEncrypted(super.message, {super.cause});
}

/// Maps a key-management failure onto the storage layer's verdict.
///
/// [databaseFileExists] must be read *before* any attempt to open, so that the
/// answer describes the disk as the user left it.
Never throwForKeyFailure(
  KeyManagementException error, {
  required bool databaseFileExists,
}) {
  switch (error) {
    case KeyStoreUnavailable():
      throw DatabaseKeyUnavailable(
        'the OS secure store could not be read, so the database was not '
        'opened. Nothing was created or modified; this may succeed on the '
        'next launch.',
        cause: error,
      );

    // The severe direction: a wrapped DEK survives but its KEK is gone. Any
    // database on disk is now permanently unopenable — provisioning a fresh key
    // over it would destroy it silently instead of failing here.
    case KeyMaterialMissing(missing: MissingKeyMaterial.kek):
      throw DatabaseKeyLost(
        'the KEK is gone while a wrapped DEK remains. An existing database '
        'can no longer be decrypted by anyone; it has been left untouched.',
        databaseFileExists: databaseFileExists,
        cause: error,
      );

    case KeyMaterialMissing(missing: MissingKeyMaterial.wrappedDek):
      throw DatabaseKeyLost(
        databaseFileExists
            ? 'the key record is gone but a database file exists. Its contents '
                'are unrecoverable. Nothing was deleted — resetting this '
                'installation is the user\'s decision to make.'
            : 'the key record is gone and no database file exists. This '
                'installation can be reset safely, but resetting is not done '
                'automatically.',
        databaseFileExists: databaseFileExists,
        cause: error,
      );

    case DekUnwrapFailed():
    case KeyStoreCorrupted():
      throw DatabaseKeyLost(
        'stored key material is unusable, so the DEK could not be recovered. '
        'The database was not opened and nothing on disk was changed.',
        databaseFileExists: databaseFileExists,
        cause: error,
      );
  }
}
