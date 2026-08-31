import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/llm_providers.dart';
import '../../../core/di/prompt_providers.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/layout/lev_shell.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/routing/destination_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lev_widgets.dart';
import '../domain/llm_errors.dart';
import 'chat_notifier.dart';
import 'chat_state.dart';
import 'start_conversation.dart';
import 'widgets/chat_composer.dart';
import 'widgets/conversation_history.dart';

/// The supportive conversation (technical-spec §5.1).
///
/// Opens straight into a conversation. The history is a drawer on mobile and a
/// permanent column on desktop — the same `ConversationHistory` widget in both,
/// handed to [LevShell.sideList].
class ChatScreen extends ConsumerWidget {
  const ChatScreen({this.conversationId, super.key});

  /// `null` on `/chat`: no conversation chosen yet.
  final String? conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The safety layer is localised for the person, not the model (§5.2.4,
    // #11): a Hebrew-reading user gets a Hebrew UI and an English assistant, and
    // must still be caught — and answered — in the language they typed in. This
    // is the only place the real locale is known.
    return ProviderScope(
      overrides: [
        safetyLocaleProvider.overrideWithValue(Localizations.localeOf(context)),
      ],
      child: _ChatShell(conversationId: conversationId),
    );
  }
}

class _ChatShell extends ConsumerWidget {
  const _ChatShell({required this.conversationId});

  final String? conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return LevShell(
      destination: LevDestination.chat,
      onDestinationChanged: (d) => goToDestination(context, d),
      title: Text(l10n.chatTitle),
      sideList: ConversationHistory(
        selectedId: conversationId,
        showSettings: !LevBreakpoint.isWide(context),
      ),
      appBarActions: [
        IconButton(
          onPressed: () => _startConversation(context, ref),
          icon: const Icon(Icons.edit_outlined),
          tooltip: l10n.conversationsNew,
        ),
      ],
      onOpenSettings: () => context.push(AppRoutes.settings),
      body: _ChatBody(conversationId: conversationId),
    );
  }

  Future<void> _startConversation(BuildContext context, WidgetRef ref) async {
    final id = await startConversation(ref);
    if (!context.mounted) return;
    context.go(AppRoutes.conversation(id));
  }
}

/// Everything between the bar and the bottom of the screen.
///
/// Three waits, in three shapes, because they are three different lengths
/// (design stage 6): the model's one-off preparation is a whole screen, the
/// session's prefill is a line that hides nothing, and the model writing is
/// three dots. A progress bar over a one-second wait feels slower than nothing.
class _ChatBody extends ConsumerWidget {
  const _ChatBody({required this.conversationId});

  final String? conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    // The engine first: until it is loaded there is no conversation to open,
    // and its failures are the ones with something specific to say.
    final engine = ref.watch(llmServiceProvider);
    if (engine.isLoading) return const _ModelPreparing();
    if (engine.hasError) {
      return _ModelFailure(
        error: engine.error!,
        onRetry: () => ref.invalidate(llmServiceProvider),
      );
    }

    final id = conversationId;
    if (id == null) {
      return LevEmptyState(
        icon: Icons.chat_bubble_outline,
        title: l10n.conversationsEmptyTitle,
        body: l10n.conversationsEmptyBody,
        action: SizedBox(
          width: 240,
          child: LevButton(
            label: l10n.homeStartChat,
            onPressed: () async {
              final newId = await startConversation(ref);
              if (!context.mounted) return;
              context.go(AppRoutes.conversation(newId));
            },
          ),
        ),
      );
    }

    final chat = ref.watch(chatNotifierProvider(id));

    return chat.when(
      // §8: the prefill must be visible, and a blank or frozen screen is a
      // defect. It is a labelled line rather than a bare spinner.
      loading: () => Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              LevSpace.md,
              LevSpace.md,
              LevSpace.md,
              0,
            ),
            child: LevBanner(text: l10n.chatPreparingSession),
          ),
          const Spacer(),
          ChatComposer(
            isBusy: true,
            enabled: false,
            onSend: (_) {},
            onStop: () {},
          ),
        ],
      ),
      error: (error, _) => LevEmptyState(
        icon: Icons.error_outline,
        tone: LevTone.warning,
        title: l10n.chatLoadFailed,
        body: l10n.chatTruncatedBody,
        footnote: l10n.aidStillWorks,
        action: SizedBox(
          width: 240,
          child: LevButton(
            label: l10n.retry,
            kind: LevButtonKind.secondary,
            onPressed: () => ref.invalidate(chatNotifierProvider(id)),
          ),
        ),
      ),
      data: (state) => _Conversation(conversationId: id, state: state),
    );
  }
}

/// The model's one-off preparation.
///
/// **No percentage.** The design shows one, and neither `LlmService.loadModel`
/// nor `ModelFileStore.pathFor` reports progress, so there is no honest number
/// to put here — and an invented one is worse than none. What can be said is
/// said: it happens once, and nothing is being downloaded.
class _ModelPreparing extends StatelessWidget {
  const _ModelPreparing();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = levColors(context);
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(LevSpace.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: c.primary,
                  borderRadius: LevRadius.bubbleAll,
                ),
                child: Icon(
                  Icons.favorite_border,
                  color: c.onPrimary,
                  size: 26,
                ),
              ),
              const SizedBox(height: LevSpace.lg),
              Text(
                l10n.chatPreparingModelTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: LevSpace.sm),
              Text(
                l10n.chatPreparingModelBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: LevSpace.lg),
              ClipRRect(
                borderRadius: LevRadius.pill,
                child: LinearProgressIndicator(minHeight: 4, color: c.primary),
              ),
              const SizedBox(height: LevSpace.sm),
              // A small line exactly where any other application would be
              // downloading something. It is a chance to prove the promise in
              // real time.
              Text(
                l10n.chatPreparingModelOffline,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The chat could not start.
///
/// Every branch ends in "mutual aid keeps working": not consolation but an
/// architectural fact (§3.1). The two capabilities are independent, so one
/// failing must never look like the application failing.
class _ModelFailure extends StatelessWidget {
  const _ModelFailure({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // The integrity failure is a refusal, not a botched attempt: a failing
    // sha256 must refuse to load rather than trying anyway (§7.5), and this
    // screen is that rule's face.
    final (String title, String body, String action) = switch (error) {
      ModelIntegrityFailed() => (
          l10n.modelIntegrityTitle,
          l10n.modelIntegrityBody,
          l10n.modelIntegrityAction,
        ),
      NoSuitableModel() => (
          l10n.modelTooSmallTitle,
          l10n.modelTooSmallBody,
          l10n.modelTooSmallAction,
        ),
      _ => (
          l10n.modelUnavailableTitle,
          l10n.modelUnavailableBody,
          l10n.retry,
        ),
    };

    return LevEmptyState(
      icon: Icons.error_outline,
      tone: LevTone.warning,
      title: title,
      body: body,
      footnote: l10n.aidStillWorks,
      action: SizedBox(
        width: 240,
        child: LevButton(
          label: action,
          kind: LevButtonKind.secondary,
          onPressed: onRetry,
        ),
      ),
    );
  }
}

class _Conversation extends ConsumerWidget {
  const _Conversation({required this.conversationId, required this.state});

  final String conversationId;
  final ChatState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(chatNotifierProvider(conversationId).notifier);
    final streaming = state.streamingText.isNotEmpty;
    final showDots = state.isTyping && !streaming;

    // Everything that is not a stored message, newest first, so it can be
    // indexed off the front of a reversed list.
    final trailing = <Widget>[
      if (state.failure != null)
        _TruncatedNotice(onRetry: notifier.retryLastTurn),
      if (showDots) LevTypingIndicator(semanticsLabel: l10n.chatTyping),
      if (streaming)
        LevBubble(text: state.streamingText, fromUser: false, isStreaming: true),
      // Alongside the reply, never in its place. It sits inside the scroll,
      // between the message and the answer — a modal here would stop the screen
      // at the most vulnerable possible moment.
      if (state.safetyNotice != null) _SupportNotice(text: state.safetyNotice!),
    ];

    if (state.messages.isEmpty && trailing.isEmpty) {
      return Column(
        children: [
          Expanded(
            child: LevEmptyState(
              icon: Icons.chat_bubble_outline,
              title: l10n.conversationsEmptyTitle,
              body: l10n.conversationsEmptyBody,
            ),
          ),
          _composer(notifier),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            // Newest at the bottom, so the view sits on the latest turn with no
            // scroll-to-end bookkeeping as tokens arrive.
            reverse: true,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: LevSpace.lg,
              vertical: LevSpace.lg,
            ),
            itemCount: state.messages.length + trailing.length,
            separatorBuilder: (_, _) => const SizedBox(height: LevSpace.md),
            itemBuilder: (context, index) {
              if (index < trailing.length) return trailing[index];
              final message =
                  state.messages[state.messages.length - 1 - (index - trailing.length)];
              return LevBubble(
                text: message.text,
                fromUser: message.isFromUser,
              );
            },
          ),
        ),
        _composer(notifier),
      ],
    );
  }

  Widget _composer(ChatNotifier notifier) => ChatComposer(
        isBusy: state.isBusy,
        enabled: true,
        onSend: notifier.send,
        onStop: notifier.cancel,
      );
}

/// The safety layer's support card.
///
/// The content comes from `assets/support/<locale>.json` rather than from the
/// pattern file (technical-decisions #24), because it needs a title, a body and
/// a dialable number that one string cannot carry. If that asset cannot be read,
/// the message still appears — as plain text on the same amber ground. Silently
/// dropping it is the one outcome not on the table.
class _SupportNotice extends ConsumerWidget {
  const _SupportNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resource = ref.watch(supportResourceProvider).value;
    if (resource == null) return _Fallback(text: text);

    return LevSupportCard(resource: resource, onCall: _call);
  }

  /// The only action on the card. `tel:`, never a web link: this is an app with
  /// no network, and a link would be a dead button.
  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    // Failure is swallowed on purpose: a device with no dialler (a desktop, in
    // most cases) should show the number and do nothing, not throw over it. The
    // number is on screen either way, which is what the card is for.
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = levColors(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(LevSpace.lg),
      decoration: BoxDecoration(
        color: c.warmSoft,
        borderRadius: LevRadius.bubbleAll,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: c.warmInk),
      ),
    );
  }
}

/// "The reply was cut off", inline in the conversation.
///
/// Whatever already arrived stays on screen and is stored — it is what the user
/// read. This says the *rest* is not coming, and offers to ask again.
class _TruncatedNotice extends StatelessWidget {
  const _TruncatedNotice({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = levColors(context);
    final theme = Theme.of(context);

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width *
              (LevBreakpoint.isWide(context) ? 0.62 : 0.82),
        ),
        child: Container(
          padding: const EdgeInsetsDirectional.all(LevSpace.lg),
          decoration: BoxDecoration(
            color: c.raised,
            border: Border.all(color: c.line),
            borderRadius: LevRadius.bubbleAll,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // Amber, not red. There is no red anywhere but the delete
                  // confirmation.
                  Icon(Icons.error_outline, size: 18, color: c.warm),
                  const SizedBox(width: LevSpace.sm),
                  Text(
                    l10n.chatTruncatedTitle,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: LevSpace.xs),
              Text(l10n.chatTruncatedBody, style: theme.textTheme.bodyMedium),
              const SizedBox(height: LevSpace.md),
              LevButton(
                label: l10n.retry,
                kind: LevButtonKind.secondary,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
