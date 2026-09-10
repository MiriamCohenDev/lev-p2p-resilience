import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/di/db_providers.dart';
import 'core/di/llm_providers.dart';
import 'core/di/settings_providers.dart';
import 'core/l10n/app_localizations.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/lev_widgets.dart';
import 'features/onboarding/presentation/welcome_screen.dart';
import 'features/settings/domain/settings.dart';

/// The root widget of LEV.
///
/// The locale follows the device unless the user has chosen otherwise
/// (technical-decisions #11); Hebrew renders right-to-left automatically through
/// `flutter_localizations`.
class LevApp extends ConsumerWidget {
  const LevApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final settings = ref.watch(settingsProvider);

    // The preferences are read from the encrypted database, so they are not
    // there on the first frame. Falling back to the defaults means the
    // application opens in the device's language and theme — which is what the
    // defaults are anyway, so nothing flashes.
    final chosen = settings.value ?? LevSettings.defaults;

    return _ModelWarmUp(
      child: MaterialApp.router(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        theme: LevTheme.light,
        darkTheme: LevTheme.dark,
        themeMode: switch (chosen.appearance) {
          LevAppearance.light => ThemeMode.light,
          LevAppearance.dark => ThemeMode.dark,
          LevAppearance.system => ThemeMode.system,
        },
        // Null hands the choice back to `supportedLocales` and the device.
        locale:
            chosen.languageCode == null ? null : Locale(chosen.languageCode!),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        builder: (context, child) =>
            _FirstRunGate(state: settings, child: child),
      ),
    );
  }
}

/// Starts the model loading when the application starts, and renders nothing.
///
/// The weights take seconds to load and the provider is kept alive, so the cost
/// is paid once per launch whatever happens — the only question is *when*, and
/// the moment someone taps Chat is the worst answer available. Until this
/// existed, the chat screen's own `ref.watch` was the first watcher in the whole
/// app, so entering the tab was what started the load and `_ModelPreparing` was
/// what the first visit of every session looked like (#35).
///
/// Three things about the shape, each load-bearing:
///
/// **`listenManual`, not `ref.watch`.** A watch would rebuild the whole
/// `MaterialApp.router` — router config, theme, locale — on each `AsyncValue`
/// transition, for a value this widget never renders. The subscription
/// instantiates the provider and holds it alive with no rebuilds at all, and
/// Riverpod closes it when this element is disposed.
///
/// **Above `MaterialApp`, not inside its `builder`.** `builder` runs again on
/// every `MaterialApp` rebuild; here the widget is built once. It is also above
/// [_FirstRunGate], so the load does not wait on the encrypted database to say
/// whether onboarding has been seen — including on a first install, where the
/// weights are extracted from the asset bundle while the welcome screen is up.
///
/// **The failure is swallowed on purpose.** A model that will not load means the
/// *chat* cannot answer, and the chat screen already owns that: it switches on
/// the failure, offers `ref.invalidate(llmServiceProvider)` as a retry — which
/// still works, and now re-runs at once because this subscription keeps the
/// provider alive — and ends, as design rule 9 requires, by saying mutual aid
/// still works. A model error raised over Home would say the opposite.
class _ModelWarmUp extends ConsumerStatefulWidget {
  const _ModelWarmUp({required this.child});

  final Widget child;

  @override
  ConsumerState<_ModelWarmUp> createState() => _ModelWarmUpState();
}

class _ModelWarmUpState extends ConsumerState<_ModelWarmUp> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(llmServiceProvider, (_, _) {});
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Shows the welcome screen until it has been accepted, and the storage failure
/// if the database cannot be opened at all.
///
/// A gate around the router rather than a `redirect` inside it. Whether the
/// welcome screen has been seen is a preference, and reading it means opening
/// the encrypted database — an asynchronous answer that a redirect would have to
/// guess at while it loads and then correct through a `refreshListenable`. Here
/// the three states are just three widgets.
///
/// It is also the first place the database's own failure modes are shown.
/// Before this, a `DatabaseKeyLost` surfaced as whatever the first screen to
/// touch storage happened to render.
class _FirstRunGate extends StatelessWidget {
  const _FirstRunGate({required this.state, required this.child});

  final AsyncValue<LevSettings> state;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return state.when(
      loading: () => const _Splash(),
      error: (error, _) => const _StorageFailure(),
      data: (settings) =>
          settings.hasSeenOnboarding ? child! : const WelcomeScreen(),
    );
  }
}

/// The logo on the canvas colour while storage opens.
///
/// Deliberately not a spinner: unlocking the database is milliseconds in the
/// ordinary case, and a spinner that appears and vanishes reads as a stutter.
/// The stacked lockup, because a splash is one of the two places the product
/// introduces itself by name.
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: LevLogo.vertical()));
  }
}

class _StorageFailure extends ConsumerWidget {
  const _StorageFailure();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: LevEmptyState(
          icon: Icons.lock_outline,
          tone: LevTone.warning,
          title: l10n.storageFailedTitle,
          body: l10n.storageFailedBody,
          action: SizedBox(
            width: 240,
            child: LevButton(
              label: l10n.retry,
              kind: LevButtonKind.secondary,
              onPressed: () => ref.invalidate(appDatabaseProvider),
            ),
          ),
        ),
      ),
    );
  }
}
