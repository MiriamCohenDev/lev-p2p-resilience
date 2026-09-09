import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';

/// The LEV logo.
///
/// **Three different things, each with a place of its own:**
///
/// | variant      | what it is        | where it belongs                        |
/// |--------------|-------------------|-----------------------------------------|
/// | [mark]       | the symbol alone  | bars, the side rail, an icon            |
/// | [horizontal] | symbol + wordmark | documents and anywhere outside the app — and, small and centred, the About signature |
/// | [vertical]   | one above the other | the first-run screen and the splash    |
///
/// **In the application's bars the wordmark does not appear** — only the mark.
/// The word is for the places the product introduces itself; a bar is not one of
/// them, and repeating the name on every screen is how a name stops being read.
///
/// Every measurement derives from [height]. There is deliberately **no image
/// file of the lockup**: it is composed from the symbol and the font, so it is
/// sharp at any resolution and can never drift out of step with either half.
///
/// The symbol is `assets/branding/*.svg`, copied verbatim from the design
/// (technical-decisions #27); the word is set in [wordmarkFont], which exists
/// for this widget and for nothing else (#28).
enum LevLogoVariant { mark, horizontal, vertical }

class LevLogo extends StatelessWidget {
  const LevLogo({
    super.key,
    this.variant = LevLogoVariant.mark,
    this.height = 28,
    this.onColor = false,
  });

  const LevLogo.mark({super.key, this.height = 28, this.onColor = false})
      : variant = LevLogoVariant.mark;

  const LevLogo.horizontal({super.key, this.height = 32, this.onColor = false})
      : variant = LevLogoVariant.horizontal;

  const LevLogo.vertical({super.key, this.height = 76, this.onColor = false})
      : variant = LevLogoVariant.vertical;

  final LevLogoVariant variant;

  /// H — the symbol's height. Every other measurement is derived from it.
  final double height;

  /// True on a turquoise or dark ground: the mark and the word both go white.
  final bool onColor;

  /// The wordmark's font. **Not the interface font.**
  ///
  /// Subset to A–Z at one weight (3.3 KB), because three letters is all it ever
  /// renders. Using it anywhere else would put the logo's voice into ordinary
  /// copy — `test/core/widgets/lev_logo_test.dart` fails the build if another
  /// file names it.
  static const String wordmarkFont = 'OutfitSemiBold';

  /// Below 24 the regular stroke smears, so there is a micro drawing with a
  /// heavier one. The threshold and both files come from the design's pack.
  static const double microAtOrBelow = 24;

  static const String _regularAsset = 'assets/branding/lev-mark.svg';
  static const String _microAsset = 'assets/branding/lev-mark-micro.svg';

  /// The symbol file a given height resolves to. Public so the choice is
  /// testable without reaching into the rendering.
  static String assetFor(double height) =>
      height <= microAtOrBelow ? _microAsset : _regularAsset;

  /// The wordmark's size for a given [height] and variant.
  ///
  /// Vertical sets the word at half the mark and horizontal at 0.85 of it: in
  /// the stacked lockup the symbol is what holds the screen, so the word sits
  /// under it rather than competing.
  static double fontSizeFor(double height, LevLogoVariant variant) =>
      height * (variant == LevLogoVariant.vertical ? 0.50 : 0.85);

  static double _gapFor(double height, LevLogoVariant variant) =>
      height * (variant == LevLogoVariant.vertical ? 0.25 : 0.30);

  @override
  Widget build(BuildContext context) {
    final c = levColors(context);
    final markColor = onColor ? c.onPrimary : c.primary;
    final textColor = onColor ? c.onPrimary : c.ink;

    final mark = SvgPicture.asset(
      assetFor(height),
      height: height,
      width: height,
      colorFilter: ColorFilter.mode(markColor, BlendMode.srcIn),
      excludeFromSemantics: true,
    );

    if (variant == LevLogoVariant.mark) {
      return Semantics(label: _semanticsLabel, image: true, child: mark);
    }

    final fontSize = fontSizeFor(height, variant);
    final gap = _gapFor(height, variant);

    final word = Text(
      _semanticsLabel,
      textDirection: TextDirection.ltr,
      style: TextStyle(
        fontFamily: wordmarkFont,
        fontWeight: FontWeight.w600,
        fontSize: fontSize,
        height: 1,
        letterSpacing: fontSize * 0.06,
        color: textColor,
      ),
    );

    final isVertical = variant == LevLogoVariant.vertical;

    return Semantics(
      label: _semanticsLabel,
      image: true,
      // Announced once, as one image. Without this the word would also be read
      // as text and a screen reader would say the name twice.
      child: ExcludeSemantics(
        // The lockup is one unit and does **not** mirror under RTL: the symbol
        // always comes before the word. What does move is where the lockup sits
        // on the screen, and that is the screen's business.
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: isVertical
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [mark, SizedBox(height: gap), word],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [mark, SizedBox(width: gap), word],
                ),
        ),
      ),
    );
  }

  /// The brand name, identical in every locale.
  ///
  /// A literal rather than an ARB lookup, and deliberately: it is not interface
  /// copy that anyone would translate, and a logo that cannot draw itself
  /// without `AppLocalizations` is a logo with a dependency it has no business
  /// having.
  static const String _semanticsLabel = 'LEV';
}
