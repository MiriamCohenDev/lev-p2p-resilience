import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/layout/lev_shell.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/routing/destination_routes.dart';
import '../../../core/widgets/lev_widgets.dart';

/// Nearby help requests and the tasks the user has taken on.
///
/// Still a placeholder — the feature is built in Phase 4, local-only, against
/// `HelpRepository` and the no-op `TransportService` stub (technical-spec
/// Section 9). It is in the design's language, but it does **not** say "no open
/// requests": that would be a lie dressed as an empty state. The feature does
/// not exist yet; it is not empty.
class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return LevShell(
      destination: LevDestination.aid,
      onDestinationChanged: (d) => goToDestination(context, d),
      title: Text(l10n.aidTitle),
      // Reachable from every destination on desktop, where the control lives at
      // the foot of the rail. On mobile the bar has no room for it and Home
      // carries it, as the design draws.
      onOpenSettings: () => context.push(AppRoutes.settings),
      body: LevEmptyState(
        icon: Icons.people_outline,
        title: l10n.aidComingSoonTitle,
        body: l10n.aidComingSoonBody,
      ),
    );
  }
}
