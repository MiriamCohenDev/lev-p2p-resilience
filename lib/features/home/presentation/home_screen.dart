import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/chat_providers.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/l10n/time_formats.dart';
import '../../../core/layout/lev_shell.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/routing/destination_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lev_widgets.dart';
import '../../chat/domain/conversation.dart';
import '../../chat/presentation/start_conversation.dart';

/// The landing screen: a greeting for the hour, one primary action, and one
/// quiet reminder of where the last conversation stopped.
///
/// **One filled button on the screen.** "Start a conversation" is the only thing
/// with a solid turquoise ground here; the card below it is tappable but quiet.
/// Two filled buttons would weaken each other.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return LevShell(
      destination: LevDestination.home,
      onDestinationChanged: (d) => goToDestination(context, d),
      title: LevWordmark(label: l10n.appTitle),
      onOpenSettings: () => context.push(AppRoutes.settings),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: LevSpace.xl,
            vertical: LevSpace.xl,
          ),
          child: Align(
            alignment: AlignmentDirectional.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: LevSpace.readableWidth,
              ),
              child: const _HomeBody(),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final part = partOfDay(DateTime.now());
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: LevSpace.sm),
        Text(l10n.greetingFor(part), style: theme.textTheme.displaySmall),
        const SizedBox(height: LevSpace.xs),
        Text(l10n.promptFor(part), style: theme.textTheme.bodyMedium),
        const SizedBox(height: LevSpace.xl),
        LevButton(
          label: l10n.homeStartChat,
          onPressed: () => _start(context, ref),
        ),
        const _ResumeSection(),
        // Home's third section in the design — "open requests · 3" — is not
        // here, and deliberately so: mutual aid is not built, and a section that
        // could only ever be empty would be furniture rather than information.
        // It arrives with `HelpRepository`.
      ],
    );
  }

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final id = await startConversation(ref);
    if (!context.mounted) return;
    context.go(AppRoutes.conversation(id));
  }
}

/// "Pick up where you left off" — the most recent conversation, or nothing.
class _ResumeSection extends ConsumerWidget {
  const _ResumeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    // Shown only when there is something to resume. On a first run this section
    // does not exist at all rather than standing empty — an empty state on the
    // landing screen would be the first thing a new user is told, and it has
    // nothing to say.
    final latest = ref.watch(conversationsProvider).maybeWhen(
          data: (items) => items.isEmpty ? null : items.first,
          orElse: () => null,
        );
    if (latest == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LevSectionLabel(l10n.homeResumeLabel),
        LevCard(
          onTap: () => context.go(AppRoutes.conversation(latest.id)),
          child: _ResumeCardContent(conversation: latest),
        ),
      ],
    );
  }
}

class _ResumeCardContent extends StatelessWidget {
  const _ResumeCardContent({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final title = conversation.title.isEmpty
        ? l10n.conversationUntitled
        : conversation.title;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: LevSpace.xs),
        Text(
          formatStamp(context, conversation.updatedAt),
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}
