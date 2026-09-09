import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/db_providers.dart';
import '../../../core/di/llm_providers.dart';
import '../../../core/di/settings_providers.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lev_widgets.dart';
import '../domain/settings.dart';
import 'about_section.dart';
import 'model_labels.dart';

/// Three groups, and nothing else.
///
/// The model is shown here because it is part of the product, not an internal
/// secret: the user sees what is running on her device, how much of it there is,
/// and when it was replaced. That is not technical curiosity — it is what proves
/// the product's central promise, which is why it belongs on a screen she sees.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings =
        ref.watch(settingsProvider).value ?? LevSettings.defaults;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: LevSpace.lg,
            vertical: LevSpace.sm,
          ),
          child: Align(
            alignment: AlignmentDirectional.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: LevSpace.readableWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LevSectionLabel(l10n.settingsGroupGeneral),
                  LevListGroup(
                    children: [
                      LevListRow(
                        title: l10n.settingsLanguage,
                        value: _languageLabel(l10n, settings.languageCode),
                        onTap: () => _chooseLanguage(context, ref, settings),
                      ),
                      LevListRow(
                        title: l10n.settingsAppearance,
                        value: _appearanceLabel(l10n, settings.appearance),
                        onTap: () => _chooseAppearance(context, ref, settings),
                        showDivider: false,
                      ),
                    ],
                  ),
                  LevSectionLabel(l10n.settingsGroupModel),
                  const _ModelGroup(),
                  LevSectionLabel(l10n.settingsGroupPrivacy),
                  LevListGroup(
                    children: [
                      // Shown, greyed, with the reason underneath. A disabled
                      // control with no explanation is a broken screen; one with
                      // an explanation is a promise.
                      LevListRow(
                        title: l10n.settingsLock,
                        subtitle: l10n.lockUnavailable,
                        semanticsHint: l10n.lockUnavailable,
                        trailing: const Switch(value: false, onChanged: null),
                      ),
                      LevListRow(
                        title: l10n.settingsDeleteAll,
                        onTap: () => _deleteEverything(context, ref),
                        showDivider: false,
                      ),
                    ],
                  ),
                  // Last, and deliberately so: the licence notices and the
                  // product's central promise have to live somewhere permanent,
                  // and this is the bottom of the one screen that is already
                  // the single way to reach them.
                  const AboutSection(),
                  const SizedBox(height: LevSpace.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _languageLabel(AppLocalizations l10n, String? code) =>
      switch (code) {
        'he' => l10n.languageHebrew,
        'en' => l10n.languageEnglish,
        _ => l10n.settingsFollowDevice,
      };

  static String _appearanceLabel(
    AppLocalizations l10n,
    LevAppearance appearance,
  ) =>
      switch (appearance) {
        LevAppearance.light => l10n.settingsAppearanceLight,
        LevAppearance.dark => l10n.settingsAppearanceDark,
        LevAppearance.system => l10n.settingsFollowDevice,
      };

  Future<void> _chooseLanguage(
    BuildContext context,
    WidgetRef ref,
    LevSettings settings,
  ) async {
    final l10n = AppLocalizations.of(context);
    final chosen = await _pick<String?>(
      context,
      title: l10n.settingsLanguage,
      current: settings.languageCode,
      options: [
        (value: null, label: l10n.settingsFollowDevice),
        (value: 'he', label: l10n.languageHebrew),
        (value: 'en', label: l10n.languageEnglish),
      ],
    );
    if (chosen == null) return;

    final repository = await ref.read(settingsRepositoryProvider.future);
    await repository.setLanguageCode(chosen.value);
  }

  Future<void> _chooseAppearance(
    BuildContext context,
    WidgetRef ref,
    LevSettings settings,
  ) async {
    final l10n = AppLocalizations.of(context);
    final chosen = await _pick<LevAppearance>(
      context,
      title: l10n.settingsAppearance,
      current: settings.appearance,
      options: [
        (value: LevAppearance.system, label: l10n.settingsFollowDevice),
        (value: LevAppearance.light, label: l10n.settingsAppearanceLight),
        (value: LevAppearance.dark, label: l10n.settingsAppearanceDark),
      ],
    );
    if (chosen == null) return;

    final repository = await ref.read(settingsRepositoryProvider.future);
    await repository.setAppearance(chosen.value);
  }

  /// Erases everything and returns the installation to its first run.
  ///
  /// Home first, then the erase: the router is still pointing at this screen,
  /// and coming back to Settings after starting over would be a strange place to
  /// land. The database is invalidated last, which is what makes the welcome
  /// gate in `LevApp` reappear — there is nothing to navigate to, because the
  /// gate sits above the router.
  Future<void> _deleteEverything(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showLevDestructiveDialog(
      context,
      title: l10n.deleteAllTitle,
      body: l10n.deleteAllBody,
      confirmLabel: l10n.deleteAllConfirm,
      cancelLabel: l10n.cancel,
    );
    if (!confirmed || !context.mounted) return;

    final eraser = await ref.read(dataEraserProvider.future);
    if (!context.mounted) return;
    context.go(AppRoutes.home);

    try {
      await eraser.eraseEverything();
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.deleteAllFailed)));
      return;
    }

    // One invalidation is enough: every storage-backed provider watches
    // `appDatabaseProvider`, so Riverpod re-runs them all — a fresh DEK, a fresh
    // empty database, and settings back at their defaults, which is what makes
    // the welcome gate reappear.
    ref.invalidate(appDatabaseProvider);
  }
}

/// The active model: its family, its language, its size, and where it runs.
class _ModelGroup extends ConsumerWidget {
  const _ModelGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final model = ref.watch(activeModelProvider).value;

    if (model == null) {
      return LevListGroup(
        children: [
          LevListRow(
            title: l10n.settingsActiveModel,
            value: l10n.modelUnavailableTitle,
            showDivider: false,
          ),
        ],
      );
    }

    final size = model.sizeInGigabytes;

    return LevListGroup(
      children: [
        LevListRow(
          title: l10n.settingsActiveModel,
          value: l10n.settingsModelValue(
            modelFamilyLabel(model.family),
            modelLanguageLabel(l10n, model.language),
          ),
          subtitle: size == null
              ? l10n.settingsModelOnDevice
              : l10n.settingsModelOnDeviceWithSize(size),
          showDivider: false,
        ),
      ],
    );
  }
}

typedef _Option<T> = ({T value, String label});

/// A choice between a handful of values, in the product's own components.
///
/// Returns `null` when the dialog was dismissed, which is why the result is
/// wrapped in a record: `null` is also a legitimate *value* here — it is what
/// "follow the device" is stored as.
Future<_Option<T>?> _pick<T>(
  BuildContext context,
  {
  required String title,
  required T current,
  required List<_Option<T>> options,
}) {
  return showDialog<_Option<T>>(
    context: context,
    builder: (context) {
      final c = levColors(context);
      return AlertDialog(
        title: Text(title),
        contentPadding: const EdgeInsetsDirectional.only(bottom: LevSpace.sm),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in options)
              LevListRow(
                title: option.label,
                showDivider: option != options.last,
                onTap: () => Navigator.of(context).pop(option),
                trailing: option.value == current
                    ? Icon(Icons.check, size: 18, color: c.primary)
                    : const SizedBox(width: LevSpace.lg),
              ),
          ],
        ),
      );
    },
  );
}
