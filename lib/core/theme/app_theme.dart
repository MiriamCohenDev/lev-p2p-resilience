import 'package:flutter/material.dart';

/// Visual theming for LEV.
///
/// **Every colour, size and spacing in the app comes from here.** A screen that
/// declares a colour of its own is a defect, not a local decision: the palette
/// below is what makes the product read as calm, and a one-off `Container` with
/// a hand-picked colour is exactly how that erodes.
///
/// The palette is deliberately muted: the product's purpose is to steady
/// someone, so nothing in the interface should compete for attention or read as
/// urgent. There is **no red in the main palette** — see [LevDestructive].
///
/// The font is bundled rather than fetched. `google_fonts` downloads on first
/// run, and technical-spec §8 makes a network call a defect rather than a
/// trade-off (technical-decisions #26).

// ═══════════════════════════════════════════════════════════════════════
// 1. Semantic colour tokens
//
// Material's `ColorScheme` has no vocabulary for the roles this product
// actually has — `raised`, `warm`, `done` — so they live in a ThemeExtension
// and `ColorScheme` is derived from them below. Read them with:
//
//   final c = Theme.of(context).extension<LevColors>()!;
//
// or, from anywhere under the widget library, `levColors(context)`.
// ═══════════════════════════════════════════════════════════════════════

@immutable
class LevColors extends ThemeExtension<LevColors> {
  const LevColors({
    required this.canvas,
    required this.surface,
    required this.raised,
    required this.ink,
    required this.muted,
    required this.disabled,
    required this.line,
    required this.lineStrong,
    required this.primary,
    required this.primaryPress,
    required this.primarySoft,
    required this.onPrimary,
    required this.warm,
    required this.warmSoft,
    required this.warmInk,
    required this.done,
    required this.doneSoft,
  });

  /// The application background.
  final Color canvas;

  /// Cards, bars, sheets.
  final Color surface;

  /// What sits on top of [surface]: chat bubbles, input fields.
  final Color raised;

  /// Primary text.
  final Color ink;

  /// Secondary text, timestamps, descriptions.
  final Color muted;

  /// Placeholders and disabled components **only** — never text meant to be
  /// read.
  final Color disabled;

  /// Dividers and card borders.
  final Color line;

  /// The border of an interactive component: an input field, a secondary
  /// button.
  final Color lineStrong;

  /// The user's action: buttons, links, the selected state.
  final Color primary;
  final Color primaryPress;

  /// A soft wash of [primary] — a status pill, a selected row.
  final Color primarySoft;
  final Color onPrimary;

  /// **Human involvement.** Someone took a help request; the safety layer's
  /// support message. That is the one rule the amber exists for — it is not a
  /// general-purpose accent, and using it for anything else spends the only
  /// signal the product has for "a person is in this".
  final Color warm;
  final Color warmSoft;
  final Color warmInk;

  /// Completed.
  final Color done;
  final Color doneSoft;

  static const light = LevColors(
    canvas: Color(0xFFF2F2EF),
    surface: Color(0xFFFBFBF9),
    raised: Color(0xFFFFFFFF),
    ink: Color(0xFF1D2A2E),
    muted: Color(0xFF5F6F73),
    disabled: Color(0xFFA2ADAF),
    line: Color(0xFFE3E3DE),
    lineStrong: Color(0xFFCFCFC8),
    primary: Color(0xFF2E6B78),
    primaryPress: Color(0xFF235761),
    primarySoft: Color(0xFFDFEBED),
    onPrimary: Color(0xFFFFFFFF),
    warm: Color(0xFF8A5A22),
    warmSoft: Color(0xFFF5EADC),
    warmInk: Color(0xFF6B4E22),
    done: Color(0xFF3D6B4F),
    doneSoft: Color(0xFFDFEAE1),
  );

  /// Dark is **not** an inversion of light.
  ///
  /// The turquoise lightens to stay legible on a dark ground, and the ink stops
  /// at `#E8EAE7` rather than pure white, which would glare in a room with the
  /// lights off. The same tokens, different values — which is the point of
  /// naming them by role instead of by colour.
  static const dark = LevColors(
    canvas: Color(0xFF14181A),
    surface: Color(0xFF1C2124),
    raised: Color(0xFF232A2D),
    ink: Color(0xFFE8EAE7),
    muted: Color(0xFF9BA6A8),
    disabled: Color(0xFF5C6668),
    line: Color(0xFF2C3336),
    lineStrong: Color(0xFF3D4649),
    primary: Color(0xFF6FB3BF),
    primaryPress: Color(0xFF8FC9D3),
    primarySoft: Color(0xFF1E3A3F),
    onPrimary: Color(0xFF0F1517),
    warm: Color(0xFFD9A76A),
    warmSoft: Color(0xFF332A1D),
    warmInk: Color(0xFFE7C494),
    done: Color(0xFF7FB08F),
    doneSoft: Color(0xFF223027),
  );

  @override
  LevColors copyWith({
    Color? canvas,
    Color? surface,
    Color? raised,
    Color? ink,
    Color? muted,
    Color? disabled,
    Color? line,
    Color? lineStrong,
    Color? primary,
    Color? primaryPress,
    Color? primarySoft,
    Color? onPrimary,
    Color? warm,
    Color? warmSoft,
    Color? warmInk,
    Color? done,
    Color? doneSoft,
  }) {
    return LevColors(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      raised: raised ?? this.raised,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      disabled: disabled ?? this.disabled,
      line: line ?? this.line,
      lineStrong: lineStrong ?? this.lineStrong,
      primary: primary ?? this.primary,
      primaryPress: primaryPress ?? this.primaryPress,
      primarySoft: primarySoft ?? this.primarySoft,
      onPrimary: onPrimary ?? this.onPrimary,
      warm: warm ?? this.warm,
      warmSoft: warmSoft ?? this.warmSoft,
      warmInk: warmInk ?? this.warmInk,
      done: done ?? this.done,
      doneSoft: doneSoft ?? this.doneSoft,
    );
  }

  @override
  LevColors lerp(ThemeExtension<LevColors>? other, double t) {
    if (other is! LevColors) return this;
    return LevColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
      line: Color.lerp(line, other.line, t)!,
      lineStrong: Color.lerp(lineStrong, other.lineStrong, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryPress: Color.lerp(primaryPress, other.primaryPress, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      warm: Color.lerp(warm, other.warm, t)!,
      warmSoft: Color.lerp(warmSoft, other.warmSoft, t)!,
      warmInk: Color.lerp(warmInk, other.warmInk, t)!,
      done: Color.lerp(done, other.done, t)!,
      doneSoft: Color.lerp(doneSoft, other.doneSoft, t)!,
    );
  }
}

/// The single destructive red, and the only red in the product.
///
/// It appears on exactly one control: the confirm button of "delete all data".
/// It is deliberately **not** in [LevColors] — putting it there would make it
/// reachable, and what gives it force when it does appear is that nothing else
/// in the interface is ever this colour. Help-request states use amber and grey;
/// so do the error screens (`LevTone.warning`).
abstract final class LevDestructive {
  static const Color light = Color(0xFF9B3B36);
  static const Color dark = Color(0xFFE0928C);

  static const Color onLight = Color(0xFFFFFFFF);
  static const Color onDark = Color(0xFF1B0F0E);

  static Color of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  static Color on(Brightness brightness) =>
      brightness == Brightness.dark ? onDark : onLight;
}

// ═══════════════════════════════════════════════════════════════════════
// 2. Spacing, corners, motion, layout
//
// A scale of 4. A value that is not on it is a design bug, not a decision.
// ═══════════════════════════════════════════════════════════════════════

abstract final class LevSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
  static const double huge = 64;

  /// The minimum touch height of anything tappable.
  static const double minTouch = 48;

  /// The widest a column of running text may get before it stops being
  /// comfortable to read. Relevant on desktop.
  static const double readableWidth = 680;
}

abstract final class LevRadius {
  static const Radius chip = Radius.circular(6);
  static const Radius button = Radius.circular(8);
  static const Radius card = Radius.circular(10);
  static const Radius bubble = Radius.circular(14);

  static const BorderRadius chipAll = BorderRadius.all(chip);
  static const BorderRadius buttonAll = BorderRadius.all(button);
  static const BorderRadius cardAll = BorderRadius.all(card);
  static const BorderRadius bubbleAll = BorderRadius.all(bubble);
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));

  /// The bubble's "tail": the corner touching the speaker's side is shortened.
  static const Radius bubbleTail = Radius.circular(5);
}

abstract final class LevMotion {
  /// A local state change: a press, a hover, a selection.
  static const Duration fast = Duration(milliseconds: 120);

  /// A screen transition, a sheet opening.
  static const Duration standard = Duration(milliseconds: 200);

  static const Curve curve = Curves.easeOut;
}

/// Where the layout changes shape.
///
/// Lives with the tokens rather than inside `LevShell` because the widget
/// library reads it too — a chat bubble is capped at a different fraction of the
/// width on either side of it — and that dependency has to point at the theme,
/// not at the layout.
abstract final class LevBreakpoint {
  /// Below this, the mobile layout — including on a desktop with a small
  /// window. This is also what settles tablets without designing for them
  /// separately.
  static const double desktop = 900;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;
}

// ═══════════════════════════════════════════════════════════════════════
// 3. Typography
//
// Six sizes. Body line height is 1.7: Hebrew has no ascenders or descenders
// to break up a line, so dense text reads as a single block.
// ═══════════════════════════════════════════════════════════════════════

const String levFontFamily = 'IBMPlexSansHebrew';

TextTheme _textTheme(LevColors c) {
  TextStyle base(
    double size,
    FontWeight weight,
    double height,
    Color color, {
    double? spacing,
  }) {
    return TextStyle(
      fontFamily: levFontFamily,
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: color,
      letterSpacing: spacing,
    );
  }

  return TextTheme(
    // display · the large screen title (Home)
    displaySmall: base(32, FontWeight.w600, 1.25, c.ink),
    // h1 · screen title
    headlineMedium: base(26, FontWeight.w600, 1.3, c.ink),
    // h2 · section title
    titleLarge: base(21, FontWeight.w600, 1.35, c.ink),
    // h3 · card title
    titleMedium: base(17, FontWeight.w600, 1.4, c.ink),
    // body · ordinary text, chat messages
    bodyLarge: base(15, FontWeight.w400, 1.7, c.ink),
    // small · descriptions, timestamps
    bodyMedium: base(13.5, FontWeight.w400, 1.6, c.muted),
    // label · list headers, pills
    labelLarge: base(12, FontWeight.w600, 1.4, c.muted, spacing: 0.48),
  );
}

// ═══════════════════════════════════════════════════════════════════════
// 4. ThemeData
// ═══════════════════════════════════════════════════════════════════════

abstract final class LevTheme {
  static ThemeData get light => _build(LevColors.light, Brightness.light);

  static ThemeData get dark => _build(LevColors.dark, Brightness.dark);

  static ThemeData _build(LevColors c, Brightness brightness) {
    final text = _textTheme(c);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: levFontFamily,
      scaffoldBackgroundColor: c.canvas,
      extensions: <ThemeExtension<dynamic>>[c],

      // Derived from the tokens rather than seeded, so a Material widget that
      // has not been themed explicitly still lands inside the palette instead
      // of somewhere near it.
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: c.primary,
        onPrimary: c.onPrimary,
        primaryContainer: c.primarySoft,
        onPrimaryContainer: c.primary,
        secondary: c.warm,
        onSecondary: c.onPrimary,
        secondaryContainer: c.warmSoft,
        onSecondaryContainer: c.warmInk,
        // Material insists on an error colour, so it is given the destructive
        // one — but nothing in LEV routes an ordinary failure through it: a
        // cancelled help request goes grey, and a model that failed to load
        // goes amber.
        error: LevDestructive.of(brightness),
        onError: LevDestructive.on(brightness),
        surface: c.surface,
        onSurface: c.ink,
        onSurfaceVariant: c.muted,
        outline: c.lineStrong,
        outlineVariant: c.line,
      ),

      textTheme: text,
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),

      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        shape: Border(bottom: BorderSide(color: c.line)),
      ),

      cardTheme: CardThemeData(
        color: c.raised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: LevRadius.cardAll,
          side: BorderSide(color: c.line),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed)
                ? c.primaryPress
                : c.primary,
          ),
          foregroundColor: WidgetStatePropertyAll(c.onPrimary),
          minimumSize: const WidgetStatePropertyAll(Size(0, LevSpace.minTouch)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: LevSpace.xl),
          ),
          textStyle: WidgetStatePropertyAll(
            text.bodyLarge?.copyWith(fontWeight: FontWeight.w600, height: 1),
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: LevRadius.buttonAll),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(c.primary),
          minimumSize: const WidgetStatePropertyAll(Size(0, LevSpace.minTouch)),
          side: WidgetStatePropertyAll(BorderSide(color: c.lineStrong)),
          textStyle: WidgetStatePropertyAll(
            text.bodyLarge?.copyWith(fontWeight: FontWeight.w600, height: 1),
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: LevRadius.buttonAll),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(c.primary),
          textStyle: WidgetStatePropertyAll(
            text.bodyLarge?.copyWith(fontWeight: FontWeight.w600, height: 1),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.raised,
        hintStyle: text.bodyLarge?.copyWith(color: c.disabled),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: LevSpace.lg,
          vertical: LevSpace.md,
        ),
        border: OutlineInputBorder(
          borderRadius: LevRadius.buttonAll,
          borderSide: BorderSide(color: c.lineStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: LevRadius.buttonAll,
          borderSide: BorderSide(color: c.lineStrong),
        ),
        // Two logical pixels of turquoise. Keyboard focus is not decoration: on
        // desktop there are people who navigate by Tab alone, and without a
        // visible ring the app is unusable for them.
        focusedBorder: OutlineInputBorder(
          borderRadius: LevRadius.buttonAll,
          borderSide: BorderSide(color: c.primary, width: 2),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: c.primarySoft,
        labelStyle: text.labelLarge?.copyWith(color: c.primary),
        side: BorderSide.none,
        shape: const RoundedRectangleBorder(borderRadius: LevRadius.pill),
        padding: const EdgeInsets.symmetric(
          horizontal: LevSpace.md,
          vertical: LevSpace.xs,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.primarySoft,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: LevRadius.pill,
        ),
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(
          text.labelLarge?.copyWith(letterSpacing: 0),
        ),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.primarySoft,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: LevRadius.pill,
        ),
        selectedLabelTextStyle: text.labelLarge?.copyWith(color: c.primary),
        unselectedLabelTextStyle: text.labelLarge,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.ink,
        contentTextStyle: text.bodyLarge?.copyWith(color: c.canvas),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: LevRadius.buttonAll),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: LevRadius.bubbleAll),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyLarge,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.line,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return c.disabled;
          return states.contains(WidgetState.selected) ? c.onPrimary : c.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return c.line;
          return states.contains(WidgetState.selected)
              ? c.primary
              : c.lineStrong;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }
}
