import 'settings.dart';

/// Reads and writes the interface preferences.
///
/// [watch] rather than a read plus a manual refresh: the appearance and the
/// language are read at the application root, and a change made three screens
/// down has to reach it without anything in between knowing that it might.
abstract class SettingsRepository {
  Stream<LevSettings> watch();

  Future<LevSettings> read();

  /// `null` means "follow the device".
  Future<void> setLanguageCode(String? languageCode);

  Future<void> setAppearance(LevAppearance appearance);

  Future<void> markOnboardingSeen(DateTime at);

  /// Erases every preference, as part of "delete all data".
  Future<void> clear();
}
