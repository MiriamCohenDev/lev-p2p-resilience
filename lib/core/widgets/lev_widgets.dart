import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../support/support_resources.dart';
import '../theme/app_theme.dart';
// Imported for `LevBrandLine`, and re-exported so a screen that imports the
// component library gets the logo with it. There is one logo in this product
// and it comes from one place.
import 'lev_logo.dart';
export 'lev_logo.dart';

/// LEV's component library.
///
/// Every screen is built from these. **A screen that writes its own `Container`
/// with a colour is a deviation from the system** — if a component is missing,
/// add it here rather than improvising in the screen, or the palette stops being
/// a palette within a month.
///
/// Two rules run through the whole file:
///   • `EdgeInsetsDirectional`, never `EdgeInsets` with left/right, so RTL works
///     without special handling (#11).
///   • `Semantics` around anything tappable — a screen reader has to be able to
///     say what it is and what will happen.
///
/// Nothing here holds a user-visible string of its own. Labels are parameters,
/// filled from `AppLocalizations` by the screen, because #11 makes a literal in
/// a widget a defect.

// `levColors` and `reduceMotion` live in `app_theme.dart`, beside the tokens
// they read, and arrive here with it.

// ═══════════════════════════════════════════════════════════════════════
// Buttons
// ═══════════════════════════════════════════════════════════════════════

enum LevButtonKind {
  /// The primary action — filled turquoise. **One per screen.** Two filled
  /// buttons on one screen weaken each other.
  primary,

  /// A secondary action — outline only.
  secondary,

  /// A destructive, irreversible action. The only red in the product.
  destructive,
}

class LevButton extends StatelessWidget {
  const LevButton({
    super.key,
    required this.label,
    this.onPressed,
    this.kind = LevButtonKind.primary,
    this.icon,
    this.expand = true,
    this.disabledHint,
  });

  final String label;

  /// `null` disables the button.
  final VoidCallback? onPressed;
  final LevButtonKind kind;
  final IconData? icon;

  /// Stretch to the parent's width (the default on mobile).
  final bool expand;

  /// **Why** the button is disabled, announced by a screen reader.
  ///
  /// A disabled button with no explanation is a broken screen; a disabled button
  /// with one is a promise. The visible half of that explanation belongs beside
  /// the button, in the screen.
  final String? disabledHint;

  @override
  Widget build(BuildContext context) {
    final c = levColors(context);
    final brightness = Theme.of(context).brightness;
    final enabled = onPressed != null;

    late final Color bg;
    late final Color fg;
    late final BorderSide side;

    switch (kind) {
      case LevButtonKind.primary:
        bg = enabled ? c.primary : c.line;
        fg = enabled ? c.onPrimary : c.disabled;
        side = BorderSide.none;
      case LevButtonKind.secondary:
        bg = Colors.transparent;
        fg = enabled ? c.primary : c.disabled;
        side = BorderSide(color: enabled ? c.lineStrong : c.line);
      case LevButtonKind.destructive:
        bg = enabled ? LevDestructive.of(brightness) : c.line;
        fg = enabled ? LevDestructive.on(brightness) : c.disabled;
        side = BorderSide.none;
    }

    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: LevSpace.sm),
        ],
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(fontWeight: FontWeight.w600, height: 1, color: fg),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      hint: enabled ? null : disabledHint,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: LevRadius.buttonAll,
          side: side,
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: LevRadius.buttonAll,
          // The pressed state is the darker shade of primary, not an opaque
          // black scrim over it.
          highlightColor: kind == LevButtonKind.primary
              ? c.primaryPress.withValues(alpha: 0.9)
              : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: LevSpace.minTouch),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: LevSpace.xl,
              vertical: LevSpace.md,
            ),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// A row's own menu
// ═══════════════════════════════════════════════════════════════════════

/// One entry in a row's menu: what it looks like, what it says, what it does.
typedef LevMenuAction = ({
  IconData icon,
  String label,
  VoidCallback onSelected,
});

/// Opens the product's row menu and runs whichever action was chosen.
///
/// Anchored on [anchor]'s own box — pass the *button's* context, not the row's,
/// or the menu opens from the middle of the row. [at] overrides that with a
/// global point, which is what a right-click wants: the menu should appear
/// under the cursor, not under a control the cursor was nowhere near.
///
/// It exists here rather than in the screen because a menu is a surface, and a
/// surface improvised per screen is how a palette stops being a palette. RTL
/// needs no handling: `showMenu` reads the ambient directionality and flips its
/// own alignment.
Future<void> showLevMenu({
  required BuildContext anchor,
  required List<LevMenuAction> actions,
  Offset? at,
}) async {
  final c = levColors(anchor);
  final text = Theme.of(anchor).textTheme;

  final overlay =
      Navigator.of(anchor).overlay!.context.findRenderObject()! as RenderBox;
  final box = anchor.findRenderObject()! as RenderBox;
  // `showMenu` positions within the overlay's coordinate space, so a global
  // point from a pointer event has to be brought into it.
  final origin = at != null
      ? overlay.globalToLocal(at)
      : box.localToGlobal(box.size.center(Offset.zero), ancestor: overlay);

  final chosen = await showMenu<VoidCallback>(
    context: anchor,
    position: RelativeRect.fromRect(
      origin & Size.zero,
      Offset.zero & overlay.size,
    ),
    color: c.surface,
    shape: RoundedRectangleBorder(
      borderRadius: LevRadius.cardAll,
      side: BorderSide(color: c.line),
    ),
    items: [
      for (final action in actions)
        PopupMenuItem<VoidCallback>(
          value: action.onSelected,
          height: LevSpace.minTouch,
          child: Row(
            children: [
              Icon(action.icon, size: 18, color: c.muted),
              const SizedBox(width: LevSpace.md),
              // Not the destructive red on "delete", even here. That colour is
              // spent on erasing the whole installation and nothing else (#28),
              // and a menu entry that shouts is a menu entry that gets misread.
              Text(action.label, style: text.bodyLarge),
            ],
          ),
        ),
    ],
  );

  chosen?.call();
}

// ═══════════════════════════════════════════════════════════════════════
// Help-request status pill
// ═══════════════════════════════════════════════════════════════════════

/// The state a help request is in.
///
/// [committed] is amber because amber means **a person is involved** — the same
/// rule the safety layer's support card follows. [cancelled] goes grey rather
/// than red: cancelling is not a failure and not an error, it is simply an end.
enum LevHelpStatus { open, committed, completed, cancelled }

class LevStatusPill extends StatelessWidget {
  const LevStatusPill(this.status, {required this.label, super.key});

  final LevHelpStatus status;

  /// The wording is human, not systemic: "someone took it", never "claimed".
  /// Whoever is scanning the list wants to know if somebody is already seeing to
  /// it — not what the database column says.
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = levColors(context);
    final (Color bg, Color fg) = switch (status) {
      LevHelpStatus.open => (c.primarySoft, c.primary),
      LevHelpStatus.committed => (c.warmSoft, c.warmInk),
      LevHelpStatus.completed => (c.doneSoft, c.done),
      LevHelpStatus.cancelled => (c.line, c.muted),
    };

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: LevSpace.md,
        vertical: LevSpace.xs,
      ),
      decoration: BoxDecoration(color: bg, borderRadius: LevRadius.pill),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: fg, letterSpacing: 0),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Card
// ═══════════════════════════════════════════════════════════════════════

class LevCard extends StatelessWidget {
  const LevCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsetsDirectional.all(LevSpace.lg),
    this.background,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Overrides the card's ground. Used for the promise card on the welcome
  /// screen, which sits on `primarySoft`; everything else leaves it null.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final c = levColors(context);
    final content = Padding(padding: padding, child: child);

    return Material(
      color: background ?? c.raised,
      shape: RoundedRectangleBorder(
        borderRadius: LevRadius.cardAll,
        // A card rests on a rule, not on a shadow.
        side: BorderSide(
          color: background == null ? c.line : Colors.transparent,
        ),
      ),
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: LevRadius.cardAll,
              child: content,
            ),
    );
  }
}

// The bar's logo was a `LevWordmark` here — the mark beside the word `LEV`, set
// in the interface font. Both halves of that were wrong: the design's bars carry
// the mark alone, and the word has a font of its own. It is `LevLogo` now, and
// this is the only place the logo comes from.

/// The small uppercase-weight label above a group of cards or settings rows.
class LevSectionLabel extends StatelessWidget {
  const LevSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: LevSpace.xl,
        bottom: LevSpace.sm,
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Chat bubble
// ═══════════════════════════════════════════════════════════════════════

class LevBubble extends StatelessWidget {
  const LevBubble({
    super.key,
    required this.text,
    required this.fromUser,
    this.isStreaming = false,
  });

  final String text;

  /// True for the user's own message.
  ///
  /// **The turquoise bubble is hers, not the model's.** The strong colour is
  /// reserved for the user's action — even when the action is a sentence she
  /// wrote. The model speaks on a white ground, quieter.
  final bool fromUser;

  /// Still arriving. Renders a caret so a paused stream is visibly *paused*
  /// rather than indistinguishable from a finished short reply, and reveals the
  /// text at reading speed rather than at whatever rate the model happens to
  /// produce it.
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final c = levColors(context);

    // On desktop the bubble stops at 62%: a line 900 pixels wide is unreadable.
    final maxFactor = LevBreakpoint.isWide(context) ? 0.62 : 0.82;

    return Align(
      alignment: fromUser
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * maxFactor,
        ),
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: LevSpace.lg,
            vertical: LevSpace.md,
          ),
          decoration: BoxDecoration(
            color: fromUser ? c.primary : c.raised,
            border: fromUser ? null : Border.all(color: c.line),
            // Directional, and left unresolved: `BoxDecoration.borderRadius`
            // takes a `BorderRadiusGeometry` and resolves it against the
            // ambient direction itself, so the tail lands on the speaker's side
            // in Hebrew and in English without a branch here.
            borderRadius: BorderRadiusDirectional.only(
              topStart: LevRadius.bubble,
              topEnd: LevRadius.bubble,
              bottomStart: fromUser ? LevRadius.bubbleTail : LevRadius.bubble,
              bottomEnd: fromUser ? LevRadius.bubble : LevRadius.bubbleTail,
            ),
          ),
          child: _content(context, c),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, LevColors c) {
    final base = Theme.of(context).textTheme.bodyLarge!
        .copyWith(color: fromUser ? c.onPrimary : c.ink);

    // **What the user wrote is never parsed.** Someone who types `**` means
    // `**`, and quietly eating her asterisks would be the application editing
    // her own words back at her.
    if (fromUser) return Text(text, style: base);

    if (!isStreaming) return LevMarkdownText(text, style: base);

    return _LevReveal(
      text: text,
      builder: (context, revealed) =>
          LevMarkdownText(revealed, style: base, isStreaming: true),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// The model's prose
// ═══════════════════════════════════════════════════════════════════════

/// The caret that marks a reply still arriving.
const String _caret = '▌';

/// The model's prose, with the small markdown subset it actually emits.
///
/// **Never used for what the user wrote** — see `LevBubble._content`.
///
/// Renders `**bold**`, `*italic*`/`_italic_`, `` `code` ``, `#` headings (as
/// bold — there is no heading scale in a chat bubble), `-`/`*`/`+` bullets and
/// `1.` numbered items, keeping the model's own numbering. **Everything else
/// passes through character for character**: links and images (an offline
/// application must never draw something tappable that cannot be tapped, #25),
/// tables, block quotes, rules, HTML, strikethrough, and fence lines.
///
/// The invariant that keeps this honest, and that `lev_markdown_test.dart`
/// pins: **for a single-paragraph source carrying no valid marker, the rendered
/// plain text is byte-identical to the source** — one `Text.rich`, no wrapper.
/// That is what lets `find.text` keep matching a bubble. A multi-block source
/// is a `Column`, so no single finder sees the whole reply.
class LevMarkdownText extends StatelessWidget {
  const LevMarkdownText(
    this.text, {
    super.key,
    this.style,
    this.isStreaming = false,
  });

  final String text;

  /// Defaults to `bodyLarge`. Every other style here is derived from it.
  final TextStyle? style;

  /// Appends the caret, and clips a marker run left dangling at the tail.
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final c = levColors(context);
    final base = style ?? Theme.of(context).textTheme.bodyLarge!;

    // A prefix ending mid-marker would render the marker literally for one
    // frame and then snap — the flicker this whole design exists to avoid. The
    // cost is at most a few characters of tail latency, hidden behind the caret.
    final source = isStreaming ? text.replaceFirst(_danglingMarkers, '') : text;
    final blocks = _parseBlocks(source);

    if (blocks.isEmpty) {
      return Text.rich(TextSpan(text: isStreaming ? _caret : ''), style: base);
    }

    Widget widgetFor(_Block block, {required bool last}) {
      final caret = last && isStreaming;
      switch (block) {
        case _Para(:final body, :final bold):
          final s = bold ? base.copyWith(fontWeight: _bold) : base;
          return Text.rich(
            TextSpan(children: _parseInline(body, s, c, caret: caret)),
            style: s,
          );
        case _Item(:final marker, :final body):
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: LevSpace.xl,
                child: Text(marker, style: base.copyWith(color: c.muted)),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(children: _parseInline(body, base, c, caret: caret)),
                  style: base,
                ),
              ),
            ],
          );
      }
    }

    // The single-paragraph case is the overwhelming majority and the one the
    // byte-identical invariant is about, so it gets no wrapper at all.
    if (blocks.length == 1 && blocks.first is _Para) {
      return widgetFor(blocks.first, last: true);
    }

    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      if (i > 0) {
        // Items in a run belong together; anything else gets a paragraph gap.
        final tight = blocks[i] is _Item && blocks[i - 1] is _Item;
        children.add(SizedBox(height: tight ? LevSpace.xs : LevSpace.sm));
      }
      children.add(widgetFor(blocks[i], last: i == blocks.length - 1));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

/// The one weight that means emphasis in this product — `LevButton`,
/// `LevSupportCard` and `_TruncatedNotice` all use it. Never w700.
const FontWeight _bold = FontWeight.w600;

final RegExp _danglingMarkers = RegExp(r'[*_`#\\]+$');
final RegExp _heading = RegExp(r'^#{1,6}\s+(.*)$');
final RegExp _bullet = RegExp(r'^[-*+]\s+(.*)$');
final RegExp _numbered = RegExp(r'^(\d{1,3})[.)]\s+(.*)$');
final RegExp _wordChar = RegExp(r'[\p{L}\p{N}_]', unicode: true);

const String _escapable = r'\*_`#';

sealed class _Block {
  const _Block();
}

class _Para extends _Block {
  const _Para(this.body, {this.bold = false});
  final String body;
  final bool bold;
}

class _Item extends _Block {
  const _Item(this.marker, this.body);
  final String marker;
  final String body;
}

/// Splits prose into blocks in one pass. Nesting is flattened to one level:
/// a chat bubble is not a document, and an indented sub-list in a supportive
/// reply is the model imitating documentation rather than talking.
List<_Block> _parseBlocks(String source) {
  final blocks = <_Block>[];
  final para = StringBuffer();

  void flush() {
    if (para.isEmpty) return;
    blocks.add(_Para(para.toString()));
    para.clear();
  }

  for (final raw in source.split('\n')) {
    final line = raw.trimLeft();

    if (line.isEmpty) {
      flush();
      continue;
    }

    final heading = _heading.firstMatch(line);
    if (heading != null) {
      flush();
      blocks.add(_Para(heading.group(1)!, bold: true));
      continue;
    }

    final bullet = _bullet.firstMatch(line);
    if (bullet != null) {
      flush();
      blocks.add(_Item('•', bullet.group(1)!));
      continue;
    }

    final numbered = _numbered.firstMatch(line);
    if (numbered != null) {
      flush();
      // The model's own number, never renumbered. If it counts 1, 2, 2, 4 that
      // is what it said, and silently correcting it would be the interface
      // claiming the model was more coherent than it was.
      blocks.add(_Item('${numbered.group(1)!}.', numbered.group(2)!));
      continue;
    }

    if (para.isNotEmpty) para.write('\n');
    para.write(line);
  }

  flush();
  return blocks;
}

/// Inline emphasis in one pass, with **three booleans rather than a stack**.
///
/// That choice is what makes streaming flicker-free: an opening marker with no
/// closer yet simply leaves its flag on to the end of the block, so `I feel
/// **that` renders bold immediately and the arriving `**` changes nothing on
/// screen. A stack would have to wait for the closer, show the marker
/// literally meanwhile, and snap.
List<InlineSpan> _parseInline(
  String source,
  TextStyle base,
  LevColors c, {
  required bool caret,
}) {
  final spans = <InlineSpan>[];
  final buffer = StringBuffer();
  var bold = false;
  var italic = false;
  var code = false;

  void flush() {
    if (buffer.isEmpty) return;
    var s = base;
    if (bold) s = s.copyWith(fontWeight: _bold);
    if (italic) s = s.copyWith(fontStyle: FontStyle.italic);
    if (code) s = s.copyWith(backgroundColor: c.line, letterSpacing: 0);
    spans.add(TextSpan(text: buffer.toString(), style: s));
    buffer.clear();
  }

  var i = 0;
  while (i < source.length) {
    final ch = source[i];

    if (ch == r'\' &&
        i + 1 < source.length &&
        _escapable.contains(source[i + 1])) {
      buffer.write(source[i + 1]);
      i += 2;
      continue;
    }

    if (ch == '`') {
      final run = _runLength(source, i);
      // A run of anything but one backtick is literal, which is how a ``` fence
      // line falls through harmlessly instead of swallowing the rest of a reply.
      if (run != 1) {
        buffer.write('`' * run);
        i += run;
        continue;
      }
      flush();
      code = !code;
      i += 1;
      continue;
    }

    // Code is verbatim: `a * b` must not come out with a * missing.
    if (code) {
      buffer.write(ch);
      i += 1;
      continue;
    }

    if (ch == '*' || ch == '_') {
      final run = _runLength(source, i);
      final take = run >= 2 ? 2 : 1;
      final opening = take == 2 ? !bold : !italic;
      if (_flanks(source, i, take, opening: opening, marker: ch)) {
        flush();
        if (take == 2) {
          bold = !bold;
        } else {
          italic = !italic;
        }
        i += take;
        continue;
      }
      buffer.write(ch * run);
      i += run;
      continue;
    }

    buffer.write(ch);
    i += 1;
  }

  flush();
  // A plain `TextSpan`, never a `WidgetSpan`: a placeholder would put U+FFFC
  // into `toPlainText()` and break every `find.text` against a bubble.
  if (caret) spans.add(TextSpan(text: _caret, style: base));
  return spans;
}

int _runLength(String source, int start) {
  final ch = source[start];
  var n = 1;
  while (start + n < source.length && source[start + n] == ch) {
    n += 1;
  }
  return n;
}

/// Whether a marker at [i] is really emphasis and not arithmetic.
///
/// An opener must be followed by a non-space, a closer preceded by one — so
/// `5 * 3 = 15` keeps its asterisk. `_` is stricter still, requiring its outer
/// neighbour to be a non-word character, so `snake_case_name` survives intact.
bool _flanks(
  String source,
  int i,
  int take, {
  required bool opening,
  required String marker,
}) {
  final before = i > 0 ? source[i - 1] : null;
  final after = i + take < source.length ? source[i + take] : null;

  if (opening) {
    if (after == null || after.trim().isEmpty) return false;
    if (marker == '_' && before != null && _wordChar.hasMatch(before)) {
      return false;
    }
    return true;
  }

  if (before == null || before.trim().isEmpty) return false;
  if (marker == '_' && after != null && _wordChar.hasMatch(after)) return false;
  return true;
}

/// Reveals a growing string at reading speed.
///
/// This exists because a local model does not produce text evenly: it stalls on
/// a cache miss and then bursts. Rendering arrival directly reads as stuttering
/// even when it is fast. Here display is decoupled from arrival — text that has
/// landed waits in [text] and is let out at a steady rate.
///
/// **Display only.** What is revealed never feeds back into what is stored, or
/// a saved conversation would depend on animation timing and a reader with
/// reduced motion would end up with a different transcript.
class _LevReveal extends StatefulWidget {
  const _LevReveal({required this.text, required this.builder});

  final String text;
  final Widget Function(BuildContext context, String revealed) builder;

  @override
  State<_LevReveal> createState() => _LevRevealState();
}

class _LevRevealState extends State<_LevReveal>
    with SingleTickerProviderStateMixin {
  /// The floor: comfortably faster than any reply this model produces, so on a
  /// phone the reveal is never structurally behind — it only spreads each
  /// arriving token over a frame or two.
  static const double _floorCps = 220;

  /// Drain whatever has arrived over this long. Bounds the backlog, and with it
  /// the jump when the finished reply replaces the streaming bubble.
  static const double _tauSeconds = 0.06;

  /// ~30 Hz. Growth at 30 Hz reads as continuous, and text relayout is the one
  /// real cost here — it runs while llama.cpp is saturating the same CPU.
  static const Duration _minInterval = Duration(milliseconds: 32);

  // A raw `Ticker`, not an `AnimationController`: there is no bounded 0→1
  // animation here because the target moves, and `repeat()` never ends — which
  // would hang every `pumpAndSettle` in the suite. This one runs only while
  // there is backlog.
  late final _ticker = createTicker(_onTick);

  int _shown = 0;
  Duration _last = Duration.zero;
  Duration _lastReveal = Duration.zero;
  bool _revealedAny = false;
  double _carry = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Here rather than `initState` because `reduceMotion` reads an inherited
    // `MediaQuery` — the same reason `LevTypingIndicator` starts here.
    _sync();
  }

  @override
  void didUpdateWidget(_LevReveal old) {
    super.didUpdateWidget(old);
    // Growth continues where it left off; a replacement jumps to the end.
    // Restarting on text that is not an extension of what is on screen would
    // replay a message the reader has already read.
    final onScreen = old.text.substring(0, math.min(_shown, old.text.length));
    if (!widget.text.startsWith(onScreen)) _shown = widget.text.length;
    _shown = math.min(_shown, widget.text.length);
    _sync();
  }

  void _sync() {
    if (reduceMotion(context)) {
      _shown = widget.text.length;
      _stop();
      return;
    }
    if (_shown < widget.text.length) {
      // Never render an empty bubble: the first grapheme is free.
      if (_shown == 0) _shown = _advance(widget.text, 0, 1);
      _start();
    } else {
      _stop();
    }
  }

  void _start() {
    if (_ticker.isActive) return;
    _reset();
    _ticker.start();
  }

  void _stop() {
    if (_ticker.isActive) _ticker.stop();
    _reset();
  }

  // `Ticker.stop()` clears its start time, so elapsed begins from zero again on
  // the next start. A stale `_last` would then produce a large negative `dt`.
  void _reset() {
    _last = Duration.zero;
    _lastReveal = Duration.zero;
    _revealedAny = false;
    _carry = 0;
  }

  void _onTick(Duration elapsed) {
    final backlog = widget.text.length - _shown;
    if (backlog <= 0) {
      _stop();
      return;
    }

    final dt =
        (elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond;
    _last = elapsed;
    if (dt <= 0) return;

    // Drain the backlog over `_tau`, but never slower than the floor. Expressed
    // per second rather than per frame so the reveal runs at the same speed
    // whatever the frame rate — including under a test's 100 ms pumps.
    _carry += math.max(_floorCps, backlog / _tauSeconds) * dt;
    if (_carry < 1) return;
    if (_revealedAny && elapsed - _lastReveal < _minInterval) return;

    final step = _carry.floor();
    _carry -= step;
    _lastReveal = elapsed;
    _revealedAny = true;
    setState(() => _shown = _advance(widget.text, _shown, step));
    if (_shown >= widget.text.length) _stop();
  }

  /// Advances by whole grapheme clusters. Slicing by code unit would split a
  /// surrogate pair or strand Hebrew niqqud from its letter for a frame.
  static int _advance(String text, int from, int step) {
    final tail = text.substring(from);
    return from + tail.characters.take(step).string.length;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, widget.text.substring(0, _shown));
}

/// Three dots: the model is writing.
///
/// The same two-or-three dots that were logo sketch 04. They stayed, in the
/// place they actually belong.
class LevTypingIndicator extends StatefulWidget {
  const LevTypingIndicator({super.key, required this.semanticsLabel});

  /// Announced as a live region, so a blind user knows the model is writing.
  final String semanticsLabel;

  @override
  State<LevTypingIndicator> createState() => _LevTypingIndicatorState();
}

class _LevTypingIndicatorState extends State<LevTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion freezes the dots rather than removing them: they are the
    // only signal that anything is happening.
    if (reduceMotion(context)) {
      _ctrl.stop();
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = levColors(context);
    final still = reduceMotion(context);

    return Semantics(
      liveRegion: true,
      label: widget.semanticsLabel,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          padding: const EdgeInsetsDirectional.all(LevSpace.lg),
          decoration: BoxDecoration(
            color: c.raised,
            border: Border.all(color: c.line),
            borderRadius: const BorderRadiusDirectional.only(
              topStart: LevRadius.bubble,
              topEnd: LevRadius.bubble,
              bottomStart: LevRadius.bubble,
              bottomEnd: LevRadius.bubbleTail,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              return Padding(
                padding: EdgeInsetsDirectional.only(
                  end: i == 2 ? 0 : LevSpace.xs + 1,
                ),
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) {
                    final t = ((_ctrl.value * 3) - i).clamp(0.0, 1.0);
                    final opacity = still
                        ? 0.6
                        : 0.28 + 0.62 * (1 - (2 * t - 1).abs());
                    return Opacity(
                      opacity: opacity,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: c.muted,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Status row (the prefill banner)
// ═══════════════════════════════════════════════════════════════════════

/// A quiet line that says what is happening without hiding anything.
///
/// Used for the session prefill: it appears when a saved conversation is opened
/// and disappears when the session is ready. The old messages are visible
/// beneath it from the first frame — there is no blank screen.
class LevBanner extends StatelessWidget {
  const LevBanner({super.key, required this.text, this.busy = true});

  final String text;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = levColors(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: LevSpace.md,
          vertical: LevSpace.sm + 1,
        ),
        decoration: BoxDecoration(
          color: c.primarySoft,
          borderRadius: LevRadius.buttonAll,
        ),
        child: Row(
          children: [
            if (busy) ...[
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: c.primary,
                ),
              ),
              const SizedBox(width: LevSpace.sm + 1),
            ],
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: c.primary, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Empty state / error state
// ═══════════════════════════════════════════════════════════════════════

enum LevTone { neutral, warning }

/// An empty screen is the first chance to explain something.
///
/// No large illustrations: a thin line icon in the rule colour, not a coloured
/// drawing. An empty state that celebrates itself becomes an obstacle; this has
/// to be quiet and to get out of the way the moment there is content.
class LevEmptyState extends StatelessWidget {
  const LevEmptyState({
    super.key,
    required this.title,
    required this.body,
    this.icon,
    this.action,
    this.footnote,
    this.tone = LevTone.neutral,
  });

  final String title;
  final String body;
  final IconData? icon;

  /// An empty state that came from a **filter** gets no action — there is
  /// nothing to do in it but change the filter, and a button there would be
  /// noise. A genuinely empty state invites; a filtered one explains.
  final Widget? action;

  /// For example: "mutual aid keeps working as usual". Every chat error ends in
  /// one of these, and it is not consolation — it is an architectural fact. The
  /// two capabilities are independent, so one failing should never look like the
  /// application failing.
  final String? footnote;

  final LevTone tone;

  @override
  Widget build(BuildContext context) {
    final c = levColors(context);
    final iconColor = switch (tone) {
      LevTone.neutral => c.lineStrong,
      LevTone.warning => c.warm,
    };

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: LevSpace.xl,
          vertical: LevSpace.xxl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 52, color: iconColor),
                const SizedBox(height: LevSpace.md),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: LevSpace.sm),
              Text(
                body,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (action != null) ...[
                const SizedBox(height: LevSpace.lg),
                action!,
              ],
              if (footnote != null) ...[
                const SizedBox(height: LevSpace.md),
                Text(
                  footnote!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(letterSpacing: 0, fontWeight: FontWeight.w400),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// The safety layer's support card
// ═══════════════════════════════════════════════════════════════════════

/// Shown **alongside** the model's reply, never in its place, and never as a
/// modal dialog.
///
/// A modal would stop the screen at the most vulnerable possible moment and feel
/// like an alarm. This is a hand held out, which can also be ignored.
///
/// The reason it never replaces the reply is in the spec (§5.2.4): a promise
/// that depends on the inference quality of a 4-bit model on an old phone is not
/// a promise. This card exists regardless of what the model says.
///
/// Its single action is `tel:`. **Not a link to a website** — this is an app
/// with no network, and a link would be a dead button. The widget does not know
/// about `url_launcher`: it takes [onCall] and the screen decides.
class LevSupportCard extends StatelessWidget {
  const LevSupportCard({
    super.key,
    required this.resource,
    required this.onCall,
  });

  final LevSupportResource resource;
  final ValueChanged<String> onCall;

  @override
  Widget build(BuildContext context) {
    final c = levColors(context);
    final text = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(LevSpace.lg),
      decoration: BoxDecoration(
        // Amber, exactly as defined: a person is entering the picture.
        color: c.warmSoft,
        borderRadius: LevRadius.bubbleAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // **No icon.** The logo is not painted amber and is reserved for the
          // bars, a Material heart beside the logo's heart would put two heart
          // shapes in one application, and any other glyph would compete with
          // what the card is saying. The card is distinct enough without one —
          // an amber ground, a bolder title, a filled call button — and without
          // it, it reads as a person reaching out rather than as a system alert,
          // which is exactly what it has to be.
          Text(
            resource.title,
            style: text.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: c.warmInk,
            ),
          ),
          const SizedBox(height: LevSpace.xs / 2),
          Text(
            resource.body,
            style: text.bodyMedium?.copyWith(color: c.warmInk),
          ),
          const SizedBox(height: LevSpace.md),
          Semantics(
            button: true,
            label: '${resource.callLabel} ${resource.phone}',
            child: Material(
              color: c.warmInk,
              borderRadius: LevRadius.buttonAll,
              child: InkWell(
                onTap: () => onCall(resource.phone),
                borderRadius: LevRadius.buttonAll,
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.call_outlined, size: 17, color: c.warmSoft),
                      const SizedBox(width: LevSpace.sm),
                      // The number is Latin digits inside a Hebrew line; the
                      // local Directionality keeps it from flipping the row.
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          '${resource.callLabel} · ${resource.phone}',
                          style: text.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1,
                            color: c.warmSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Filter selector
// ═══════════════════════════════════════════════════════════════════════

class LevSegmented extends StatelessWidget {
  const LevSegmented({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = levColors(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: c.lineStrong),
        borderRadius: LevRadius.buttonAll,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                selected: i == selected,
                button: true,
                child: InkWell(
                  onTap: () => onChanged(i),
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: LevSpace.minTouch - 6,
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: LevSpace.sm,
                      vertical: LevSpace.sm,
                    ),
                    decoration: BoxDecoration(
                      color: i == selected ? c.primarySoft : null,
                      border: BorderDirectional(
                        start: i == 0
                            ? BorderSide.none
                            : BorderSide(color: c.lineStrong),
                      ),
                    ),
                    child: Text(
                      labels[i],
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: i == selected ? c.primary : c.muted,
                        fontWeight: i == selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Settings row
// ═══════════════════════════════════════════════════════════════════════

class LevListRow extends StatelessWidget {
  const LevListRow({
    super.key,
    required this.title,
    this.value,
    this.valueDirection,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.showDivider = true,
    this.semanticsHint,
  });

  final String title;
  final String? value;

  /// Forces the reading direction of [value].
  ///
  /// A version, a model name or a phone number is Latin inside a Hebrew row.
  /// Left to the ambient direction, its leading and trailing punctuation
  /// resolves RTL and the value renders back-to-front — `(build 1) 1.0.0`.
  /// Pass [TextDirection.ltr] for anything that is not a translated sentence.
  final TextDirection? valueDirection;

  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// A secondary action on the same row — the About section's version row
  /// copies itself with it.
  ///
  /// A long press is invisible, so a row that carries one **must** say so in
  /// [semanticsHint]: a screen-reader user has no other way to learn it is
  /// there, and the pointer has no hover state on a settings row to reveal it.
  final VoidCallback? onLongPress;

  final bool showDivider;

  /// Announced after the title. Carries the "why" of a disabled control — see
  /// the lock row in Settings — and the "what happens" of an [onLongPress].
  final String? semanticsHint;

  /// The most of the row a [value] may take before it starts wrapping.
  ///
  /// The title keeps the rest. Both halves are readable at the split, and it
  /// only ever binds when the two together would not have fitted anyway.
  @override
  Widget build(BuildContext context) {
    final c = levColors(context);
    final text = Theme.of(context).textTheme;

    return MergeSemantics(
      child: Semantics(
        hint: semanticsHint,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            constraints: const BoxConstraints(minHeight: LevSpace.minTouch),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: LevSpace.lg,
              vertical: LevSpace.md,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: showDivider ? c.line : Colors.transparent,
                ),
              ),
            ),
            child: _content(text, c),
          ),
        ),
      ),
    );
  }

  Widget _content(TextTheme text, LevColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            // Title and value share one inner row, and both are `Flexible`.
            //
            // A non-flex child of a `Row` is laid out with an unbounded main
            // axis, so a plain `Text` value overflows the moment title + value
            // exceed the row — which at 200% text scale, in a narrow window, or
            // after a longer translation, they do. Flexing both caps each at
            // half the row, and `spaceBetween` hands the slack that is left to
            // the gap *between* them, so a short value still sits hard against
            // the chevron instead of leaving a hole beside it.
            //
            // Deliberately **not** a `LayoutBuilder` measuring the row and
            // capping the value against it. That reads better and breaks
            // `AlertDialog`, which wraps its content in `IntrinsicWidth` and
            // therefore asks its children for intrinsic dimensions —
            // a question `LayoutBuilder` cannot answer, so every row in the
            // language and appearance pickers threw instead of rendering.
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: Text(title, style: text.bodyLarge)),
                  if (value != null)
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: LevSpace.sm,
                        ),
                        child: Text(
                          value!,
                          style: text.bodyMedium,
                          textDirection: valueDirection,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: LevSpace.sm),
              trailing!,
            ] else if (onTap != null) ...[
              const SizedBox(width: LevSpace.xs),
              // Mirrors itself under RTL without a branch here.
              Icon(Icons.chevron_left, size: 18, color: c.muted),
            ],
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: LevSpace.xs),
          Text(
            subtitle!,
            style: text.labelLarge?.copyWith(
              letterSpacing: 0,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }
}

/// A group of [LevListRow]s on one card ground, as Settings draws them.
class LevListGroup extends StatelessWidget {
  const LevListGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = levColors(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.raised,
        borderRadius: LevRadius.cardAll,
        border: Border.all(color: c.line),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// About
//
// Three components the About section needed and the library did not have. They
// live here rather than in the screen for the reason at the top of this file:
// a screen that assembles its own coloured row is where the palette starts
// coming apart.
// ═══════════════════════════════════════════════════════════════════════

/// The logo, small and centred, as a signature at the head of a section.
///
/// **It is [LevLogo.horizontal] and nothing hand-assembled.** The mark beside a
/// `Text` spelling the name out is precisely the lockup #28 took out of the
/// bars: it sets the wordmark in the interface face, which turns the product's
/// name into a heading that happens to say it. The word belongs to the logo, in
/// the logo's own font, and there is a variant that draws exactly that.
///
/// [LevLogo.vertical] is the other candidate and is wrong here for the opposite
/// reason: the stacked lockup is how the product introduces itself, and it
/// belongs to the splash and the first run. This is a signature at the bottom
/// of a settings screen. At [height] the symbol also takes the pack's heavier
/// `micro` drawing, which is what keeps it from reading as a smudge.
class LevBrandLine extends StatelessWidget {
  const LevBrandLine({super.key});

  /// Small enough to take the micro geometry, large enough to read as the mark.
  static const double height = 20;

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [LevLogo.horizontal(height: height)],
    );
  }
}

/// A few plain statements, one under the other, on a card.
///
/// No bullets and no icons: these are sentences the reader is meant to read,
/// and a bullet in front of each turns them into a feature list — which is the
/// one thing this text must not read as.
class LevFactList extends StatelessWidget {
  const LevFactList(this.lines, {super.key});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return LevCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final line in lines) ...[
            if (line != lines.first) const SizedBox(height: LevSpace.md),
            Text(line, style: text.bodyLarge),
          ],
        ],
      ),
    );
  }
}

/// A phone number that can be selected, on a row that can dial it.
///
/// The number is a [SelectableText] and not a label, which is why this is not
/// simply a [LevListRow]: on a desktop with no dialler the only thing left to
/// do with a number is copy it, and a number that cannot be selected is a
/// number that has to be transcribed by hand from the screen.
///
/// That is also why the row itself is not an [InkWell]. A tap target wrapping
/// selectable text swallows the drag that selects it, so the dial action sits
/// on its own control at the end of the row and the text is left alone.
///
/// `tel:`, never a web address — this is an app with no network, and a link
/// would be a dead button. Like [LevSupportCard], this widget does not know
/// `url_launcher` exists: it takes [onCall] and the screen decides.
class LevContactRow extends StatelessWidget {
  const LevContactRow({
    super.key,
    required this.title,
    required this.phone,
    required this.callLabel,
    this.subtitle,
    this.onCall,
    this.showDivider = true,
  });

  final String title;
  final String phone;

  /// What the dial control announces. Shown to a screen reader, not drawn.
  final String callLabel;

  final String? subtitle;

  /// Null on a platform with no dialler: the number still shows, and there is
  /// simply no control beside it.
  final ValueChanged<String>? onCall;

  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final c = levColors(context);
    final text = Theme.of(context).textTheme;

    return Container(
      constraints: const BoxConstraints(minHeight: LevSpace.minTouch),
      padding: const EdgeInsetsDirectional.only(start: LevSpace.lg),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: showDivider ? c.line : Colors.transparent),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: LevSpace.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: text.bodyLarge),
                  if (subtitle != null) Text(subtitle!, style: text.bodyMedium),
                  const SizedBox(height: LevSpace.xs),
                  // Latin digits inside a Hebrew line: the local Directionality
                  // keeps the number from flipping the row it sits in.
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: SelectableText(
                      phone,
                      style: text.bodyLarge?.copyWith(color: c.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onCall != null)
            Semantics(
              button: true,
              label: '$callLabel $phone',
              child: InkWell(
                onTap: () => onCall!(phone),
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: LevSpace.minTouch,
                  height: LevSpace.minTouch,
                  child: _CallGlyph(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CallGlyph extends StatelessWidget {
  const _CallGlyph();

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.call_outlined,
      size: 18,
      color: levColors(context).primary,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Destructive confirmation — the only red
// ═══════════════════════════════════════════════════════════════════════

Future<bool> showLevDestructiveDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  required String cancelLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actionsPadding: const EdgeInsetsDirectional.fromSTEB(
        LevSpace.lg,
        0,
        LevSpace.lg,
        LevSpace.lg,
      ),
      // One `Row` rather than two entries: `AlertDialog.actions` lays its
      // children out in an `OverflowBar`, which gives them no incoming width
      // constraint, so an `Expanded` directly inside it throws.
      actions: [
        Row(
          children: [
            Expanded(
              child: LevButton(
                label: cancelLabel,
                kind: LevButtonKind.secondary,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            const SizedBox(width: LevSpace.sm + 1),
            Expanded(
              child: LevButton(
                label: confirmLabel,
                kind: LevButtonKind.destructive,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return result ?? false;
}
