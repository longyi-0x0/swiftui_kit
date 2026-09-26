// What the glass itself looks like: body tone, rim, hairline, shadow and edge
// refraction.

import 'package:flutter/material.dart';

/// The flat body tone used when the refraction shader is unavailable.
///
/// Measured against the native glass by placing both on the same flat backing
/// and sampling the middle of the glass, away from the labels and the selection
/// plate: on backings of 21.9 / 226.5 / 255 the native glass reads 25.8 / 247.3
/// / 253.0. The amount lifted therefore follows the backing — +3.9 at 22, +20.8
/// at 226.5, -2.0 at 255 — which is why the body is normally computed by the
/// shader instead; see [glassTone].
///
/// In dark mode it darkens instead: 255 reads 107, 53 reads 37, 22 reads 27, and
/// 50 on a photograph — that is 0.341 times the backing plus 20, a near-black
/// veil.
///
/// This function is the approximation used without the shader: the tone measured
/// on a white backing, which does not follow the backing.
({Color color, double opacity}) glassBody(bool isDark) => isDark
    ? (color: const Color(0xFF202020), opacity: 0.66)
    : (color: const Color(0xFFFAFAFA), opacity: 0.88);

/// How the shader lifts the glass body:
/// `lift * (1 - L)^power + gain * L + floor`, after which [chroma] keeps that
/// fraction of the backing's own colour (0 is fully grey, 1 keeps all of it).
///
/// Light mode uses `0.922 * (1 - L)^1.7`: the white backing stays within ±2 of
/// the native value (253 against 250), light grey 227 gives 246 against 247,
/// and dark 22 gives 224 against 26 — the one case that diverges noticeably.
/// A chroma of 0.40 keeps two fifths of the backing colour (a native chroma of
/// 66 on a photograph comes out at 24).
///
/// Dark mode is a straight line that darkens instead: gain -0.659 and floor
/// 0.0784, with almost all of the backing colour kept.
({double lift, double power, double gain, double floor, double chroma})
    glassTone(
  bool isDark,
) =>
        isDark
            ? (lift: 0, power: 1, gain: -0.659, floor: 0.0784, chroma: 0.95)
            : (lift: 0.922, power: 1.7, gain: 0, floor: 0, chroma: 0.40);

/// The measurements of the glass material itself.
abstract final class GlassMaterial {
  /// Blur radius.
  static const double blur = 20;

  /// How much of the backing's saturation is kept; dark mode keeps more.
  static const double saturateLight = 1.15;
  static const double saturateDark = 1.30;

  /// An extra lift applied to the whole surface in light mode, which is where
  /// the frosted look comes from.
  static const double brighten = 0.04;

  /// The floating shadow. Measured: below the glass the backing darkens by only
  /// about 8 levels, and anything heavier reads as a solid block.
  static const double shadowBlurNear = 8;
  static const double shadowBlurFar = 3;
  static const Offset shadowOffsetNear = Offset(0, 3);
  static const Offset shadowOffsetFar = Offset(0, 1);
  static const double shadowSpreadNear = -2;
  static const double shadowSpreadFar = -1;
  static const double shadowAlphaNearLight = 0.07;
  static const double shadowAlphaNearDark = 0.22;
  static const double shadowAlphaFarLight = 0.03;
  static const double shadowAlphaFarDark = 0.14;

  /// The rim highlight. Only the top-left and bottom-right arcs are lit; the
  /// rest is barely visible.
  ///
  /// Measured on the circular control: 224–229 on the top-left arc and 207–220
  /// on the bottom-right one, while the bottom-left and top-right arcs stay at
  /// the body tone, around 185.
  static const double rimInset = 0.4;
  static const double rimWidth = 0.8;

  /// The length of one rim segment. The rim is walked in steps of this size and
  /// each segment is lit from its own normal.
  static const double rimStep = 2.0;
  static const double rimAlphaLight = 0.62;
  static const double rimAlphaDark = 0.38;

  /// The two light directions, pointing towards the light, normalised and in
  /// screen coordinates.
  static const Offset lightTopLeft = Offset(-0.70710678, -0.70710678);
  static const Offset lightBottomRight = Offset(0.70710678, 0.70710678);

  /// The dark hairline outside the rim. Without it the outline of a capsule
  /// blurs away on a white backing.
  static const double hairlineInflate = 0.2;
  static const double hairlineWidth = 0.7;
  static const double hairlineAlphaLight = 0.10;
  static const double hairlineAlphaDark = 0.16;

  /// Edge refraction values, passed to `shaders/liquid_glass.frag`.
  static const double refractionEdgeWidth = 22;
  static const double refractionAmount = 9;

  /// A thin bright glow along the rim. It shares the two light sources above,
  /// so it overlaps the rim highlight; the measured 31 levels come mostly from
  /// the highlight, and this layer only adds a little.
  static const double refractionSpecular = 0.10;
}
