import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/chat_providers.dart';
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
/// The history is a drawer on mobile and a permanent column on desktop — the
/// same `ConversationHistory` widget in both, handed to [LevShell.sideList].
class ChatScreen extends ConsumerWidget {
  const ChatScreen({this.conversationId, this.initialMessage, super.key});

  /// `null` on `/chat`: a conversation that does not exist yet.
  ///
  /// That is a screen of its own now, not a moment on the way into one
  /// (technical-decisions #34) — a composer with nothing behind it, which is
  /// what entering the chat actually is until something has been said.
  final String? conversationId;

  /// The message that brought us here, on the way in from the draft.
  ///
  /// Carried as `GoRouterState.extra` rather than through a provider, because
  /// `/chat` and `/chat/:id` are two different route builders under two
  /// different [ProviderScope]s: plain constructor data crosses that boundary
  /// with nothing to reason about. Sent once, by `_ChatBody`, as soon as the
  /// session is open.
  final String? initialMessage;

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
      child: _ChatShell(
        conversationId: conversationId,
        initialMessage: initialMessage,
      ),
    );
  }
}

class _ChatShell extends ConsumerWidget {
  const _ChatShell({required this.conversationId, this.initialMessage});

  final String? conversationId;
  final String? initialMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return LevShell(
      destination: LevDestination.chat,
      onDestinationChanged: (d) => goToDestination(context, d),
      // The bar names the conversation that is open, as the design draws it on
      // both layouts. One line, ellipsised: a derived title runs to sixty
      // graphemes, which no bar has room for.
      title: Text(
        _title(ref) ?? l10n.chatTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      sideList: ConversationHistory(
        selectedId: conversationId,
        showSettings: !LevBreakpoint.isWide(context),
      ),
      appBarActions: [
        IconButton(
          // Goes to the empty draft; it creates nothing. Pressing "new" and
          // crossing into the tab now mean the same thing, because the thing
          // they used to differ about — an untitled row in the history — is
          // exactly what #34 removed.
          onPressed: () => context.go(AppRoutes.chat),
          icon: const Icon(Icons.edit_outlined),
          tooltip: l10n.conversationsNew,
        ),
      ],
      onOpenSettings: () => context.push(AppRoutes.settings),
      body: _ChatBody(
        conversationId: conversationId,
        initialMessage: initialMessage,
      ),
    );
  }

  /// The open conversation's own name, or null to fall back to "Chat".
  ///
  /// Null covers every state where there is no name to show: no conversation
  /// chosen, the list still loading, and — the one worth spelling out — a
  /// conversation that has not been spoken in yet, whose title is empty until
  /// `ChatNotifier` derives one from the opening message. The list writes
  /// `conversationUntitled` in that gap because a row with no text at all is
  /// unclickable; a bar has "Chat" to fall back on, which says the same thing
  /// without announcing an absence.
  ///
  /// Read from [conversationsProvider] rather than fetched here, so a rename or
  /// the derived title lands in the bar the moment it is stored.
  String? _title(WidgetRef ref) {
    final id = conversationId;
    if (id == null) return null;

    final conversations = ref.watch(conversationsProvider).value;
    if (conversations == null) return null;

    for (final conversation in conversations) {
      if (conversation.id != id) continue;
      return conversation.title.isEmpty ? null : conversation.title;
    }
    return null;
  }
}

/// Everything between the bar and the bottom of the screen.
///
/// Three waits, in three shapes, because they are three different lengths
/// (design stage 6): the model's one-off preparation is a whole screen, the
/// session's prefill is a line that hides nothing, and the model writing is
/// three dots. A progress bar over a one-second wait feels slower than nothing.
class _ChatBody extends ConsumerStatefulWidget {
  const _ChatBody({required this.conversationId, this.initialMessage});

  final String? conversationId;
  final String? initialMessage;

  @override
  ConsumerState<_ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends ConsumerState<_ChatBody> {
  /// Whether the message carried in from the draft has been handed to the
  /// notifier. Held here rather than in `_Conversation` because this element
  /// survives the loading → data rebuild that builds `_Conversation` for the
  /// first time.
  bool _sentInitial = false;

  @override
  void didUpdateWidget(_ChatBody old) {
    super.didUpdateWidget(old);
    // A different conversation in the same slot is a different message to send.
    // Every path that creates one goes through `/chat` first, which pops this
    // page, so this should not arise — but the failure it guards against is a
    // message silently dropped, and that is not a thing to leave to routing.
    if (old.conversationId != widget.conversationId) _sentInitial = false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // The engine first, in both states. It used to come second, so that a
    // conversation — which is created out of storage, not out of a model —
    // could be opened while the weights loaded. Nothing is created here any
    // more, and the one thing the draft does need is the model, so loading it
    // the moment the tab is entered is what keeps the first reply as close as
    // it can be to the one before it (#34).
    final engine = ref.watch(llmServiceProvider);
    if (engine.isLoading) return const _ModelPreparing();
    if (engine.hasError) {
      return _ModelFailure(
        error: engine.error!,
        onRetry: () => ref.invalidate(llmServiceProvider),
      );
    }

    // Nothing chosen: a conversation that does not exist yet, and will not until
    // something is said in it.
    final id = widget.conversationId;
    if (id == null) return const _DraftConversation();

    final chat = ref.watch(chatNotifierProvider(id));

    return chat.when(
      // §8: the prefill must be visible, and a blank or frozen screen is a
      // defect. It is a labelled line rather than a bare spinner.
      loading: () => const _PreparingSession(),
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
      data: (state) {
        _sendInitialMessage(id, state);
        return _Conversation(conversationId: id, state: state);
      },
    );
  }

  /// Sends the message the draft was carrying, once the session is open.
  ///
  /// The draft has no session to send through — there was no conversation to
  /// open one for — so the message crosses the navigation and is sent here, at
  /// the first moment there is anything to send it with.
  ///
  /// Two guards, and they cover different failures. [_sentInitial] stops a
  /// second dispatch across the rebuilds of one screen; `messages.isEmpty` stops
  /// it even if this state object is replaced, because by then the message it
  /// was carrying is already in the conversation. A duplicate here would say
  /// something the user said once, twice.
  void _sendInitialMessage(String id, ChatState state) {
    final text = widget.initialMessage;
    if (text == null || _sentInitial || state.messages.isNotEmpty) return;
    _sentInitial = true;

    // After the frame: this runs inside `build`, and a notifier must not be
    // written to while the tree that reads it is being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(chatNotifierProvider(id).notifier).send(text));
    });
  }
}

/// `/chat` with nothing chosen: a conversation that does not exist yet.
///
/// **Nothing is created by arriving here** (technical-decisions #34). The screen
/// is the same invitation and the same composer an empty conversation shows —
/// what is missing is the row in the history, which is the point: opening a tab
/// is not starting a conversation, sending a prompt is.
///
/// Stateful for the moment between the two: creating the conversation is a write
/// to the encrypted database, and it can fail.
class _DraftConversation extends ConsumerStatefulWidget {
  const _DraftConversation();

  @override
  ConsumerState<_DraftConversation> createState() => _DraftConversationState();
}

class _DraftConversationState extends ConsumerState<_DraftConversation> {
  /// The conversation is being created. Brief, and covered by the composer's own
  /// busy state rather than by a screen of its own.
  bool _isCreating = false;

  /// Why it could not be created, once that has happened.
  ///
  /// Only storage can fail here — a model that cannot be resolved does not stop
  /// a conversation being created (see [startConversation]) — and a chat that
  /// silently shows nothing on a storage failure is the blank screen §8 calls a
  /// defect. So it is reported, with the same words and the same retry the
  /// conversation itself uses when its history cannot be read.
  Object? _failure;

  /// What the user typed, kept for that retry. The composer clears its field on
  /// submit, so without this a storage failure would also lose the message.
  String? _pending;

  Future<void> _send(String text) async {
    setState(() {
      _pending = text;
      _failure = null;
      _isCreating = true;
    });

    try {
      final id = await startConversation(ref);
      if (!mounted) return;
      context.go(AppRoutes.conversation(id), extra: text);
      // Cleared even though we are leaving: `/chat` stays mounted underneath
      // `/chat/<id>` — go_router builds a page per matched route — so this same
      // state object is what comes back when the conversation is deleted or a
      // new one is started. Left set, it would strand the composer on its stop
      // button.
      setState(() {
        _pending = null;
        _isCreating = false;
      });
    } on Object catch (failure) {
      if (!mounted) return;
      setState(() {
        _failure = failure;
        _isCreating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_failure != null) {
      return LevEmptyState(
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
            onPressed: () => unawaited(_send(_pending ?? '')),
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: LevEmptyState(
            icon: Icons.chat_bubble_outline,
            title: l10n.conversationsEmptyTitle,
            body: l10n.conversationsEmptyBody,
          ),
        ),
        ChatComposer(
          isBusy: _isCreating,
          enabled: true,
          onSend: (text) => unawaited(_send(text)),
          // Nothing is generating yet, so there is nothing to stop. The composer
          // only offers the stop button while `isBusy`, which here is the
          // fraction of a second the write takes.
          onStop: () {},
        ),
      ],
    );
  }
}

/// The wait before a conversation can be typed into.
///
/// §8: the prefill must be visible, and a blank or frozen screen is a defect. It
/// is a labelled line rather than a bare spinner, over a composer that is
/// visibly not ready yet.
///
/// This is where the cost of #34 lands: with no conversation to open a session
/// for, the prefill can no longer start when the tab is entered, so it happens
/// here — between the first message being sent and its reply beginning. The
/// model's own load, which is the larger wait, still starts on arrival.
class _PreparingSession extends StatelessWidget {
  const _PreparingSession();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
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
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: c.primary,
                  borderRadius: LevRadius.bubbleAll,
                ),
                child: const Center(
                  child: LevLogo.mark(height: 32, onColor: true),
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
      // Keyed so the reveal's state can only ever be the streaming bubble's.
      // `LevBubble` serves both roles with no key, so a future reordering of
      // this list could otherwise graft a history bubble's element — and its
      // reveal progress — onto the reply in flight.
      if (streaming)
        LevBubble(
          key: const ValueKey('lev.chat.streaming'),
          text: state.streamingText,
          fromUser: false,
          isStreaming: true,
        ),
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
