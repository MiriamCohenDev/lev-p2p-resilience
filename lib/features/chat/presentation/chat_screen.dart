import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/prompt_providers.dart';
import '../../../core/l10n/app_localizations.dart';
import 'chat_notifier.dart';
import 'chat_state.dart';
import 'widgets/chat_composer.dart';
import 'widgets/message_bubble.dart';

/// The supportive conversation (technical-spec §5.1).
///
/// In Phase 2 this runs against `FakeLlmService`; Phase 3.1 swaps the engine and
/// nothing in this file changes.
class ChatScreen extends ConsumerWidget {
  const ChatScreen({required this.conversationId, super.key});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The safety layer is localised for the person, not the model (§5.2.4,
    // #11): a Hebrew-reading user gets a Hebrew UI and an English assistant, and
    // must still be caught by patterns written in the language they typed in.
    // This is the only place the real locale is known.
    return ProviderScope(
      overrides: [
        safetyLocaleProvider.overrideWithValue(Localizations.localeOf(context)),
      ],
      child: _ChatScaffold(conversationId: conversationId),
    );
  }
}

class _ChatScaffold extends ConsumerWidget {
  const _ChatScaffold({required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final chat = ref.watch(chatNotifierProvider(conversationId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.chatTitle)),
      body: chat.when(
        // §8: the prefill must be visible. A blank or frozen screen is a defect,
        // so this is a labelled state rather than a bare spinner.
        loading: () => _Centered(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(l10n.chatPreparing, textAlign: TextAlign.center),
            ],
          ),
        ),
        error: (error, _) => _Centered(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.chatLoadFailed, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () =>
                    ref.invalidate(chatNotifierProvider(conversationId)),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (state) => _ChatBody(
          conversationId: conversationId,
          state: state,
        ),
      ),
    );
  }
}

class _ChatBody extends ConsumerWidget {
  const _ChatBody({required this.conversationId, required this.state});

  final String conversationId;
  final ChatState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(chatNotifierProvider(conversationId).notifier);
    final streaming = state.streamingText.isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: state.messages.isEmpty && !streaming
              ? _Centered(
                  child: Text(l10n.chatEmpty, textAlign: TextAlign.center),
                )
              : ListView.builder(
                  // Newest at the bottom, so the view sits on the latest turn
                  // without any scroll-to-end bookkeeping as tokens arrive.
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  itemCount: state.messages.length + (streaming ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (streaming && index == 0) {
                      return MessageBubble(
                        text: state.streamingText,
                        isFromUser: false,
                        isStreaming: true,
                      );
                    }
                    final offset = streaming ? index - 1 : index;
                    final message =
                        state.messages[state.messages.length - 1 - offset];
                    return MessageBubble(
                      text: message.text,
                      isFromUser: message.isFromUser,
                    );
                  },
                ),
        ),
        if (state.safetyNotice != null) _SafetyNotice(text: state.safetyNotice!),
        if (state.isTyping && !streaming)
          _Status(label: l10n.chatTyping, showSpinner: true),
        if (state.failure != null)
          _Status(
            label: l10n.chatFailed,
            action: TextButton(
              onPressed: notifier.dismissFailure,
              child: Text(l10n.dismiss),
            ),
          ),
        ChatComposer(
          isBusy: state.isBusy,
          enabled: true,
          onSend: notifier.send,
          onStop: notifier.cancel,
        ),
      ],
    );
  }
}

/// The fixed support message from the safety layer (§5.2.4).
///
/// Rendered **alongside** the conversation, never in place of a reply.
class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(color: colors.onTertiaryContainer),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.label, this.showSpinner = false, this.action});

  final String label;
  final bool showSpinner;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          if (showSpinner) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(padding: const EdgeInsets.all(24), child: child),
      );
}
