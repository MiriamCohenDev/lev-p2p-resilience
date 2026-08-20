import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';

/// The supportive conversation with the local language model.
///
/// Placeholder for now — the feature is built in Phase 3, on top of the
/// `LlmService` and `ChatRepository` interfaces (technical-spec Section 9).
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.chatTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.chatComingSoon,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
