import '../../../core/l10n/app_localizations.dart';

/// How the active model is written on screen.
///
/// Settings shows it twice — once under "Language model", and once in About
/// with the attribution its licence requires beneath it. Two views of one fact,
/// so they have to be written the same way: two formatters would drift, and a
/// screen that describes the same model differently in two places reads as a
/// screen that is unsure which one is running.

/// `qwen` → `Qwen`.
///
/// The manifest's own vocabulary, capitalised for display — deliberately not a
/// translated table, or adding a model family would become a code change
/// (§5.3).
String modelFamilyLabel(String family) =>
    family.isEmpty ? family : family[0].toUpperCase() + family.substring(1);

/// A model's language code as a reader's word for it, or the code itself when
/// the interface has no word for that language yet.
String modelLanguageLabel(AppLocalizations l10n, String code) => switch (code) {
  'he' => l10n.languageHebrew,
  'en' => l10n.languageEnglish,
  _ => code,
};
