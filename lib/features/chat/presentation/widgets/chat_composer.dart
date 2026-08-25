import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';

/// The message field and its send / stop button.
///
/// Stateful because the controller belongs to the field, not to the
/// conversation: a half-typed message must survive the rebuild that every
/// streamed token causes.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    required this.onSend,
    required this.onStop,
    required this.isBusy,
    required this.enabled,
    super.key,
  });

  final ValueChanged<String> onSend;
  final VoidCallback onStop;

  /// A reply is streaming or the session is prefilling.
  final bool isBusy;

  /// False while the conversation cannot accept input at all.
  final bool enabled;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isBusy || !widget.enabled) return;
    _controller.clear();
    widget.onSend(text);
    // Keeps the keyboard up between turns; a conversation is a sequence, not a
    // series of separate errands.
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: l10n.chatInputHint,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // While generating, the same slot offers a way out. §8 calls a
            // frozen screen a defect; a send button that does nothing is the
            // same defect with a nicer coat of paint.
            widget.isBusy
                ? IconButton.filled(
                    onPressed: widget.onStop,
                    icon: const Icon(Icons.stop_rounded),
                    tooltip: l10n.chatStop,
                  )
                : IconButton.filled(
                    onPressed: widget.enabled ? _submit : null,
                    icon: const Icon(Icons.send_rounded),
                    tooltip: l10n.chatSend,
                  ),
          ],
        ),
      ),
    );
  }
}
