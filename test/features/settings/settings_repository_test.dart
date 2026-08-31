// `isNull` is both drift's SQL helper and the matcher; the matcher is the one
// this file means.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lev/core/db/app_database.dart';
import 'package:lev/features/settings/data/drift_settings_repository.dart';
import 'package:lev/features/settings/domain/settings.dart';

/// The interface preferences, against the real table (technical-decisions #23).
void main() {
  late AppDatabase database;
  late DriftSettingsRepository repository;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftSettingsRepository(database.preferencesDao);
  });

  tearDown(() => database.close());

  test('an untouched installation follows the device and has not onboarded',
      () async {
    final settings = await repository.read();

    expect(settings.languageCode, isNull);
    expect(settings.appearance, LevAppearance.system);
    expect(settings.hasSeenOnboarding, isFalse);
  });

  test('a chosen language and appearance are stored and read back', () async {
    await repository.setLanguageCode('he');
    await repository.setAppearance(LevAppearance.dark);

    final settings = await repository.read();
    expect(settings.languageCode, 'he');
    expect(settings.appearance, LevAppearance.dark);
  });

  test('choosing "follow the device" again removes the row, not writes a third '
      'value', () async {
    await repository.setLanguageCode('en');
    await repository.setLanguageCode(null);

    expect((await repository.read()).languageCode, isNull);
    expect(
      await database.preferencesDao.read(PreferenceKeys.languageCode),
      isNull,
      reason: 'following the device is the absence of a choice, not a sentinel',
    );
  });

  test('the stored appearance is the wire name, not the Dart identifier',
      () async {
    // Renaming the Dart constant must not silently change the meaning of rows
    // already on disk — the same rule `MessageRole.wireName` follows.
    await repository.setAppearance(LevAppearance.light);
    expect(
      await database.preferencesDao.read(PreferenceKeys.appearance),
      'light',
    );
  });

  test('an unreadable appearance falls back to the device rather than throwing',
      () async {
    await database.preferencesDao.write(PreferenceKeys.appearance, 'chartreuse');

    expect((await repository.read()).appearance, LevAppearance.system);
  });

  test('an unparseable onboarding stamp reads as "not seen"', () async {
    await database.preferencesDao.write(PreferenceKeys.onboardingSeenAt, 'soon');

    // The cost is that the welcome screen appears once more, which is far
    // cheaper than refusing to open the application.
    expect((await repository.read()).hasSeenOnboarding, isFalse);
  });

  test('the stream reports a change without being asked again', () async {
    final seen = <LevAppearance>[];
    final subscription =
        repository.watch().listen((s) => seen.add(s.appearance));
    addTearDown(subscription.cancel);

    await repository.setAppearance(LevAppearance.dark);
    await pumpEventQueue();

    expect(seen, contains(LevAppearance.dark));
  });

  test('clearing removes every preference', () async {
    await repository.setLanguageCode('he');
    await repository.setAppearance(LevAppearance.dark);
    await repository.markOnboardingSeen(DateTime.now());

    await repository.clear();

    final settings = await repository.read();
    expect(settings.languageCode, isNull);
    expect(settings.appearance, LevAppearance.system);
    expect(settings.hasSeenOnboarding, isFalse);
  });
}
