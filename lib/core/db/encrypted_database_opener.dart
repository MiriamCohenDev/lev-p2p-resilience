import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';

import '../crypto/crypto_errors.dart';
import '../crypto/key_manager.dart';
import '../crypto/key_material.dart';
import 'database_errors.dart';

/// Opens a SQLCipher-encrypted database file with the DEK from [keyManager].
///
/// The order here is the safety property, not an implementation detail: the DEK
/// is obtained **before** anything touches the filesystem, so a key failure
/// leaves the disk untouched by construction rather than by cleanup. See
/// [throwForKeyFailure] for what each key failure means once it gets here.
///
/// Throws a [DatabaseOpenException]; never returns an executor for an
/// unencrypted database.
Future<QueryExecutor> openEncryptedDatabase({
  required KeyManager keyManager,
  required File file,
}) async {
  // Read before opening, so the verdict describes the disk as the user left it.
  final fileExisted = file.existsSync();

  final Uint8List dek;
  try {
    dek = await keyManager.obtainDek();
  } on KeyManagementException catch (error) {
    throwForKeyFailure(error, databaseFileExists: fileExisted);
  }

  return encryptedExecutor(file: file, dek: dek);
}

/// Builds the executor for [file] keyed with [dek], which is wiped here.
///
/// Split out from [openEncryptedDatabase] so tests can drive the SQLCipher path
/// with a known key without going through a [KeyManager].
QueryExecutor encryptedExecutor({
  required File file,
  required Uint8List dek,
}) {
  // `x'<64 hex>'` — the raw-key form, which skips SQLCipher's own PBKDF2. The
  // DEK is already 32 random bytes, so there is nothing to stretch.
  final key = toSqlCipherKey(dek);
  // Our copy only: obtainDek hands out a fresh list each call. The hex string
  // cannot be wiped — Dart strings are immutable — and lives until collected.
  // That is inherent to the `PRAGMA key` API, not a choice made here.
  wipe(dek);

  file.parent.createSync(recursive: true);

  return NativeDatabase(
    file,
    // Never true. Statement logging would print the PRAGMA below, and with it
    // the key that the whole DEK/KEK scheme exists to keep off the disk.
    logStatements: false,
    setup: (db) => _keyAndVerify(db, key),
  );
}

/// Runs before any other statement on a freshly opened connection.
void _keyAndVerify(Database db, String key) {
  // Must be first. SQLCipher applies the key to the connection, and any
  // statement executed ahead of it is run against an unkeyed database.
  //
  // The double quotes are required: SQLCipher parses the pragma's value as a
  // string, so the raw-key form has to be quoted *inside* it. Passing the blob
  // literal bare is a syntax error. The key is hex only, so nothing here can be
  // escaped out of.
  db.execute('PRAGMA key = "$key";');

  _assertCipherActive(db);

  // SQLite ignores foreign keys unless asked, per connection. Without this the
  // `references` declarations in app_database.dart are documentation rather than
  // a constraint, and an orphaned message would be accepted silently.
  db.execute('PRAGMA foreign_keys = ON;');

  // Forces the header read, so a key that does not match this file fails here —
  // at open — instead of at the first query somewhere deep in a screen.
  try {
    db.execute('SELECT count(*) FROM sqlite_master;');
  } on SqliteException catch (error) {
    // Reaching this means a file with content exists and the DEK does not open
    // it: key material restored onto a different database, or a corrupted file.
    throw DatabaseKeyLost(
      'the database file could not be decrypted with this device\'s DEK. The '
      'file was left untouched.',
      databaseFileExists: true,
      cause: error,
    );
  }
}

/// Fails unless the linked SQLite really is SQLCipher.
///
/// This is the guard the whole feature hangs on. Plain SQLite does not reject
/// `PRAGMA key` — it **ignores it silently** and goes on to create a perfectly
/// ordinary plaintext database. A misconfigured build would therefore look
/// entirely healthy while writing user data to disk in the clear, which is the
/// one outcome CLAUDE.md rules out absolutely. `PRAGMA cipher_version` returns
/// no rows on plain SQLite and the cipher's version on SQLCipher.
void _assertCipherActive(Database db) {
  final ResultSet result;
  try {
    result = db.select('PRAGMA cipher_version;');
  } on SqliteException catch (error) {
    throw DatabaseNotEncrypted(
      'PRAGMA cipher_version failed, so this build is not SQLCipher. Check '
      'hooks.user_defines.sqlite3.source in pubspec.yaml.',
      cause: error,
    );
  }

  final version = result.isEmpty ? null : result.first.values.first as String?;
  if (version == null || version.isEmpty) {
    throw const DatabaseNotEncrypted(
      'PRAGMA cipher_version returned nothing: this build links plain SQLite, '
      'which ignores PRAGMA key and would store user data in plaintext. Check '
      'hooks.user_defines.sqlite3.source in pubspec.yaml.',
    );
  }
}
