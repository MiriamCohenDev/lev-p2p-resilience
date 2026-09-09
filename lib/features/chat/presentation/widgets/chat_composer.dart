import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';

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
    final c = levColors(context);

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.line)),
        ),
        padding: const EdgeInsetsDirectional.all(LevSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _SendButton(
              // While generating, the same slot offers a way out. §8 calls a
              // frozen screen a defect; a send button that does nothing is the
              // same defect with a nicer coat of paint.
              icon: widget.isBusy ? Icons.stop_rounded : Icons.send_rounded,
              tooltip: widget.isBusy ? l10n.chatStop : l10n.chatSend,
              onPressed: widget.isBusy
                  ? widget.onStop
                  : (widget.enabled ? _submit : null),
            ),
            const SizedBox(width: LevSpace.sm),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(hintText: l10n.chatInputHint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The one filled control in the composer: a turquoise square, on the end side.
class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = levColors(context);
    final enabled = onPressed != null;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: Material(
          color: enabled ? c.primary : c.line,
          borderRadius: LevRadius.buttonAll,
          child: InkWell(
            onTap: onPressed,
            borderRadius: LevRadius.buttonAll,
            child: SizedBox(
              width: LevSpace.minTouch,
              height: LevSpace.minTouch,
              child: Icon(
                icon,
                size: 20,
                color: enabled ? c.onPrimary : c.disabled,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
