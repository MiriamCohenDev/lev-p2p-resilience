import 'package:flutter/material.dart';

import '../support/support_resources.dart';
import '../theme/app_theme.dart';
// Re-exported so a screen that imports the component library gets the logo with
// it. There is one logo in this product and it comes from one place.
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
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1,
                  color: fg,
                ),
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
    position: RelativeRect.fromRect(origin & Size.zero, Offset.zero & overlay.size),
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
        style: Theme.of(context)
            .textTheme
            .labelLarge
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
        side: BorderSide(color: background == null ? c.line : Colors.transparent),
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
  /// rather than indistinguishable from a finished short reply.
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
          child: Text(
            isStreaming ? '$text▌' : text,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: fromUser ? c.onPrimary : c.ink),
          ),
        ),
      ),
    );
  }
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
                    final opacity =
                        still ? 0.6 : 0.28 + 0.62 * (1 - (2 * t - 1).abs());
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: c.primary,
                      fontWeight: FontWeight.w500,
                    ),
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
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        letterSpacing: 0,
                        fontWeight: FontWeight.w400,
                      ),
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
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showDivider = true,
    this.semanticsHint,
  });

  final String title;
  final String? value;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  /// Announced after the title. Carries the "why" of a disabled control — see
  /// the lock row in Settings.
  final String? semanticsHint;

  @override
  Widget build(BuildContext context) {
    final c = levColors(context);
    final text = Theme.of(context).textTheme;

    return MergeSemantics(
      child: Semantics(
        hint: semanticsHint,
        child: InkWell(
          onTap: onTap,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title, style: text.bodyLarge)),
                    if (value != null) Text(value!, style: text.bodyMedium),
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
            ),
          ),
        ),
      ),
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
