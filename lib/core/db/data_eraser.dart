import 'dart:io';

import '../crypto/key_manager.dart';
import 'app_database.dart';

/// Erases everything this installation holds.
///
/// With no server, this is the only way to start over, which is why it is
/// reachable from Settings rather than buried — and why it sits behind an
/// explicit confirmation.
///
/// **The order is the whole of it.** The database file goes first and the key
/// material second. Reversed, an interruption between the two leaves an
/// encrypted database that nothing can open and that the application can no
/// longer offer to delete, because the screen offering it needs the database to
/// start. This way round, an interruption leaves at worst a stored KEK with no
/// record — the loud `MissingKeyMaterial.wrappedDek` state, which a fresh
/// provision recovers from safely once the file is already gone.
class DataEraser {
  const DataEraser({
    required this.database,
    required this.keyManager,
    required this.file,
  });

  final AppDatabase database;
  final KeyManager keyManager;

  /// `lev.db` itself. Its `-wal` and `-shm` companions are derived from it.
  final File file;

  Future<void> eraseEverything() async {
    // Closed before the file is touched: on Windows an open handle makes the
    // delete fail outright, and a half-erased installation is the one state
    // this must not produce.
    await database.close();

    // The journal files as well. SQLite in WAL mode keeps recently written
    // pages in `-wal`, so deleting only the main file can leave the last
    // conversation's ciphertext on disk — encrypted, but still there, which is
    // not what the user was told would happen.
    for (final path in ['${file.path}-wal', '${file.path}-shm', file.path]) {
      final companion = File(path);
      if (await companion.exists()) await companion.delete();
    }

    await keyManager.destroyKeyMaterial();
  }
}
