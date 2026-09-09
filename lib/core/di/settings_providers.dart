import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/data/drift_settings_repository.dart';
import '../../features/settings/domain/settings.dart';
import '../../features/settings/domain/settings_repository.dart';
import '../db/data_eraser.dart';
import 'crypto_providers.dart';
import 'db_providers.dart';

/// Interface-preference wiring. Hand-written providers, per technical-decisions
/// #10.

final settingsRepositoryProvider = FutureProvider<SettingsRepository>((
  ref,
) async {
  final database = await ref.watch(appDatabaseProvider.future);
  return DriftSettingsRepository(database.preferencesDao);
});

/// The interface preferences, live.
///
/// Watched at the application root, so choosing a theme or a language three
/// screens down takes effect without anything in between knowing it might.
final settingsProvider = StreamProvider<LevSettings>((ref) async* {
  final repository = await ref.watch(settingsRepositoryProvider.future);
  yield* repository.watch();
});

/// Erases every conversation, every preference and the key material behind them.
///
/// A provider rather than a method on a screen because it needs three things
/// that are wired here and nowhere else — the open database, the key manager,
/// and the file's location.
final dataEraserProvider = FutureProvider<DataEraser>((ref) async {
  return DataEraser(
    database: await ref.watch(appDatabaseProvider.future),
    keyManager: ref.watch(keyManagerProvider),
    file: await ref.watch(appDatabaseFileProvider.future),
  );
});
