import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The LEV mark.
///
/// **Not `Icons.favorite_border`.** The logo is an *open* heart: two separate
/// strokes that stop short of meeting, at the top of the cleft and again at the
/// point. Material's outlined heart is a single closed outline — near enough to
/// pass a glance, and wrong enough to notice beside the launcher icon.
///
/// Rendered from the design's own SVG rather than from a path transcribed into
/// Dart or a coloured PNG (technical-decisions #27). The SVG stays the one
/// source of truth: redrawing the logo is replacing a file under
/// `assets/branding/`, with nothing to keep in step by hand.
class LevMark extends StatelessWidget {
  const LevMark({super.key, required this.size, required this.color});

  /// The side of the square the mark is drawn in, in logical pixels.
  final double size;

  /// The mark is a single-colour silhouette, so this paints all of it.
  ///
  /// It has to be a parameter rather than baked into the asset: the same mark is
  /// turquoise on the canvas, white on a filled square and amber on the support
  /// card — and the turquoise itself differs between light and dark
  /// (`#2E6B78` / `#6FB3BF`). The pack's pre-coloured files cover two of those
  /// four cases.
  final Color color;

  static const String _regular = 'assets/branding/lev-mark.svg';

  /// A second geometry, with a heavier stroke, for small sizes.
  ///
  /// This is what the logo pack's `micro` file is for: at 20 logical pixels the
  /// regular 3.4 stroke thins out until the mark reads as a smudge.
  static const String _micro = 'assets/branding/lev-mark-micro.svg';

  /// Below this, [_micro] is used.
  static const double microBelow = 24;

  /// Which of the two drawings [size] gets. Public so the choice is testable
  /// without reaching into the rendering.
  static bool isMicro(double size) => size < microBelow;

  /// The asset a given size resolves to.
  static String assetFor(double size) => isMicro(size) ? _micro : _regular;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      assetFor(size),
      width: size,
      height: size,
      // `srcIn` over the whole picture: the SVG strokes in `currentColor`, and
      // this is what stands in for it.
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      // The mark is decorative everywhere it appears — it sits beside the
      // wordmark, or inside a control that already has its own label — so it is
      // deliberately left out of the semantics tree rather than announced as an
      // unnamed image.
      excludeFromSemantics: true,
    );
  }
}
