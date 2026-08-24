import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../db/app_database.dart';
import '../db/encrypted_database_opener.dart';
import 'crypto_providers.dart';

/// Encrypted-storage wiring. Hand-written providers, per technical-decisions
/// #10.

/// Where the application database lives.
///
/// Application *support*, not documents: this is app state, not something the
/// user should find and open. Exposed as a provider so a test can point it at a
/// temporary directory.
final appDatabaseFileProvider = FutureProvider<File>((ref) async {
  final directory = await getApplicationSupportDirectory();
  return File(p.join(directory.path, 'lev.db'));
});

/// The encrypted application database.
///
/// Nothing is caught here on purpose. A failure to obtain the DEK arrives at the
/// UI as an `AsyncError` carrying the exact `DatabaseOpenException` subtype —
/// the difference between "retry, the keyring was locked" and "this data cannot
/// be recovered" is the caller's to act on, and swallowing it would erase it.
final appDatabaseProvider = FutureProvider<AppDatabase>((ref) async {
  final file = await ref.watch(appDatabaseFileProvider.future);
  final keyManager = ref.watch(keyManagerProvider);

  // Clears key material the committed wrapping mode does not use — the debris an
  // interrupted mode switch leaves behind (technical-decisions #12). A no-op
  // until PIN mode exists, but it belongs here rather than in a separate startup
  // hook: the sweep is about key material, and this is what consumes it.
  await keyManager.sweepIncompleteRewrap();

  final executor = await openEncryptedDatabase(
    keyManager: keyManager,
    file: file,
  );

  final database = AppDatabase(executor);
  ref.onDispose(database.close);
  return database;
});
