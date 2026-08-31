import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/settings_providers.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lev_widgets.dart';

/// The first thing a new installation shows.
///
/// One screen: what the application is, the promise that everything stays on the
/// device, and one offer to turn on a lock — with the warning in the place it
/// cannot be missed.
///
/// **There is no "skip".** There is nothing to skip: one screen, one button.
/// Every additional screen here is a price paid before anything has been
/// received.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _accepting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = levColors(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: LevSpace.xl,
              vertical: LevSpace.xxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: c.primary,
                        borderRadius: LevRadius.bubbleAll,
                      ),
                      child: Icon(
                        Icons.favorite_border,
                        color: c.onPrimary,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(height: LevSpace.lg),
                  Text(
                    l10n.appTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: LevSpace.sm),
                  Text(
                    l10n.welcomeTagline,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: LevSpace.xl),
                  LevCard(
                    background: c.primarySoft,
                    child: Text(
                      l10n.welcomePrivacy,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: c.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: LevSpace.md),
                  const _LockOffer(),
                  const SizedBox(height: LevSpace.xl),
                  LevButton(
                    label: l10n.welcomeStart,
                    onPressed: _accepting ? null : _accept,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _accept() async {
    setState(() => _accepting = true);
    final repository = await ref.read(settingsRepositoryProvider.future);
    await repository.markOnboardingSeen(DateTime.now());
    // Nothing to navigate to: the gate in `LevApp` is watching this preference
    // and swaps this screen for the router the moment it lands.
  }
}

/// The offer to lock with a code.
///
/// **The switch is off by default, and here it is disabled outright.** Per the
/// spec the ordinary mode is a KEK in the operating system's secure store, so
/// the application opens smoothly — a code is a choice, not an entry condition.
/// PIN mode itself (an Argon2-derived KEK) is not built, so the control is
/// shown, greyed, with a line underneath saying why: a disabled control with no
/// explanation is a broken screen, and one with an explanation is a promise.
///
/// The warning stays regardless. "There is no server" is a lovely promise right
/// up until the moment somebody loses everything because of it, so it is in the
/// body of the card, at the same size as the rest of the text, and before the
/// decision — not in small print.
class _LockOffer extends StatelessWidget {
  const _LockOffer();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = levColors(context);
    final theme = Theme.of(context);

    return Semantics(
      enabled: false,
      hint: l10n.lockUnavailable,
      child: LevCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.lock_outline, size: 18, color: c.muted),
                const SizedBox(width: LevSpace.sm),
                Expanded(
                  child: Text(
                    l10n.welcomeLockTitle,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Switch(value: false, onChanged: null),
              ],
            ),
            const SizedBox(height: LevSpace.xs),
            Text(l10n.welcomeLockWarning, style: theme.textTheme.bodyMedium),
            const SizedBox(height: LevSpace.xs),
            Text(
              l10n.lockUnavailable,
              style: theme.textTheme.labelLarge?.copyWith(
                letterSpacing: 0,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
