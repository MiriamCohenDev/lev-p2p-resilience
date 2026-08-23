import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/routing/app_routes.dart';

/// The application's main screen: a brief statement of LEV's purpose, plus
/// quick navigation into the two capabilities (product-spec Section 6).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.homeTagline, style: textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  Text(l10n.homeDescription, style: textTheme.bodyLarge),
                  const SizedBox(height: 40),
                  FilledButton(
                    onPressed: () => context.go(AppRoutes.chat),
                    child: Text(l10n.homeOpenChat),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () => context.go(AppRoutes.tasks),
                    child: Text(l10n.homeOpenTasks),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
