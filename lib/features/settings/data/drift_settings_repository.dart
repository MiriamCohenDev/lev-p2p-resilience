import '../../../core/db/app_database.dart';
import '../domain/settings.dart';
import '../domain/settings_repository.dart';

/// [SettingsRepository] over the `preferences` table.
///
/// The mapping between the stored strings and the domain values lives here and
/// nowhere else, which is what lets the domain stay free of both drift and
/// Flutter.
class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository(this._dao);

  final PreferencesDao _dao;

  @override
  Stream<LevSettings> watch() => _dao.watchAll().map(_fromRows);

  @override
  Future<LevSettings> read() async => _fromRows({
        for (final key in const [
          PreferenceKeys.languageCode,
          PreferenceKeys.appearance,
          PreferenceKeys.onboardingSeenAt,
        ])
          if (await _dao.read(key) case final String value) key: value,
      });

  @override
  Future<void> setLanguageCode(String? languageCode) =>
      _dao.write(PreferenceKeys.languageCode, languageCode);

  @override
  Future<void> setAppearance(LevAppearance appearance) =>
      _dao.write(PreferenceKeys.appearance, appearance.wireName);

  @override
  Future<void> markOnboardingSeen(DateTime at) =>
      _dao.write(PreferenceKeys.onboardingSeenAt, at.toIso8601String());

  @override
  Future<void> clear() => _dao.clear();

  static LevSettings _fromRows(Map<String, String> rows) {
    final seenAt = rows[PreferenceKeys.onboardingSeenAt];
    return LevSettings(
      languageCode: rows[PreferenceKeys.languageCode],
      appearance: LevAppearance.parse(rows[PreferenceKeys.appearance]),
      // A timestamp that cannot be parsed is treated as absent rather than as an
      // error: the cost is that the welcome screen appears once more, which is
      // a great deal cheaper than refusing to open the application over it.
      onboardingSeenAt: seenAt == null ? null : DateTime.tryParse(seenAt),
    );
  }
}
