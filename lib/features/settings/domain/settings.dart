/// What the user has chosen about the interface itself.
///
/// Pure Dart, with no Flutter types in it. `Locale` and `ThemeMode` belong to
/// the framework, and §3.2 keeps the domain free of it — the presentation layer
/// maps [languageCode] and [LevAppearance] onto them, which is also where the
/// device's own answer is known.
library;

/// The keys these values are stored under in the `preferences` table.
///
/// Namespaced strings rather than bare words: this table will hold more than the
/// interface's settings before long, and a key called `locale` would be the
/// first collision.
abstract final class PreferenceKeys {
  static const String languageCode = 'ui.languageCode';
  static const String appearance = 'ui.appearance';
  static const String onboardingSeenAt = 'onboarding.seenAt';
}

/// Light, dark, or whatever the operating system says.
///
/// [system] is the default, and it is not a neutral one: in an evening
/// application it is the whole point. Someone whose phone is dark at night
/// should not have to go looking for a setting.
enum LevAppearance {
  system,
  light,
  dark;

  /// The value as stored. Written out rather than using [name] so that renaming
  /// the Dart constant cannot silently change the meaning of rows already on
  /// disk — the same rule `MessageRole.wireName` follows (technical-decisions
  /// #15).
  String get wireName => switch (this) {
        LevAppearance.system => 'system',
        LevAppearance.light => 'light',
        LevAppearance.dark => 'dark',
      };

  /// Parses a stored value, falling back to [system].
  ///
  /// Unlike a message role, an unreadable appearance is not worth refusing to
  /// start over: the worst case is that the interface opens in the device's
  /// theme, which is the default anyway.
  static LevAppearance parse(String? stored) => switch (stored) {
        'light' => LevAppearance.light,
        'dark' => LevAppearance.dark,
        _ => LevAppearance.system,
      };
}

/// The interface preferences, as one value.
class LevSettings {
  const LevSettings({
    this.languageCode,
    this.appearance = LevAppearance.system,
    this.onboardingSeenAt,
  });

  /// `'he'`, `'en'`, or **null for "follow the device"**.
  ///
  /// Null rather than a third sentinel value: following the device is the
  /// absence of a choice, and a sentinel would mean every reader had to know it
  /// (technical-decisions #11 keeps the device as the default).
  final String? languageCode;

  final LevAppearance appearance;

  /// When the first-run screen was accepted, or null if it has not been.
  ///
  /// A timestamp rather than a boolean: it costs the same and it answers "since
  /// when" as well as "whether", which is the question that gets asked when a
  /// support conversation starts with "it has been doing this since…".
  final DateTime? onboardingSeenAt;

  bool get hasSeenOnboarding => onboardingSeenAt != null;

  /// What a device with nothing stored yet looks like.
  static const LevSettings defaults = LevSettings();

  LevSettings copyWith({
    String? languageCode,
    LevAppearance? appearance,
    DateTime? onboardingSeenAt,
    bool clearLanguageCode = false,
  }) =>
      LevSettings(
        languageCode:
            clearLanguageCode ? null : (languageCode ?? this.languageCode),
        appearance: appearance ?? this.appearance,
        onboardingSeenAt: onboardingSeenAt ?? this.onboardingSeenAt,
      );

  @override
  bool operator ==(Object other) =>
      other is LevSettings &&
      other.languageCode == languageCode &&
      other.appearance == appearance &&
      other.onboardingSeenAt == onboardingSeenAt;

  @override
  int get hashCode => Object.hash(languageCode, appearance, onboardingSeenAt);
}
