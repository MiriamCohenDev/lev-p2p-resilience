import 'package:flutter/material.dart';

/// One turn in the conversation.
///
/// Sides are chosen with [AlignmentDirectional] and `EdgeInsetsDirectional`
/// rather than left/right, so the layout mirrors itself under Hebrew (#11)
/// instead of stranding the user's messages on the wrong edge.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.text,
    required this.isFromUser,
    this.isStreaming = false,
    super.key,
  });

  final String text;
  final bool isFromUser;

  /// Still arriving. Renders a cursor so a paused stream is visibly *paused*
  /// rather than indistinguishable from a finished short reply.
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final background = isFromUser ? colors.primaryContainer : colors.surfaceContainerHighest;
    final foreground =
        isFromUser ? colors.onPrimaryContainer : colors.onSurface;

    return Align(
      alignment:
          isFromUser ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        // A bubble that spans the full width stops reading as a bubble, and long
        // assistant replies are the common case here.
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            isStreaming ? '$text▌' : text,
            style: theme.textTheme.bodyLarge?.copyWith(color: foreground),
          ),
        ),
      ),
    );
  }
}
