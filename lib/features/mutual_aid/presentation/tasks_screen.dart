import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';

/// Nearby help requests and the tasks the user has taken on.
///
/// Placeholder for now — the feature is built in Phase 4, local-only, against
/// the `HelpRepository` and the no-op `TransportService` stub
/// (technical-spec Section 9).
class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tasksTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.tasksComingSoon,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
