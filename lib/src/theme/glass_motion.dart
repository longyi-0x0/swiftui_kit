// Durations and curves for the fallback renderer's animations.

import 'package:flutter/animation.dart';

/// The animations played by the glass.
///
/// The native renderer takes its timing from the system — the selection
/// indicator snaps into place instead of sliding — so these values describe the
/// fallback renderer only. They are chosen so that the two renderers feel the
/// same when seen side by side.
abstract final class GlassMotion {
  /// The curve used when one selection replaces another.
  static const Curve ease = Cubic(0.32, 0.72, 0, 1);
  static const Curve fadeOut = Curves.easeOut;
  static const Curve shrink = Curves.easeOutCubic;

  /// Press feedback: scale down, then back.
  static const double pressScale = 0.94;
  static const Duration press = Duration(milliseconds: 120);

  /// Fade-in when the surface is mounted.
  ///
  /// The native renderer is a platform view, and its first frame arrives late —
  /// about 100 ms after mount — whereas the fallback renderer paints in the same
  /// frame as the rest of the content. Fading the fallback in over the same
  /// interval keeps the two appearances aligned.
  static const Duration entranceFade = Duration(milliseconds: 120);

  /// Resizing a glass surface that has a fixed width or height.
  static const Duration width = Duration(milliseconds: 280);

  /// Entering or leaving search on a title bar.
  static const Duration titleMorph = Duration(milliseconds: 340);

  /// Entering or leaving search on a capsule bar.
  static const Duration capsuleMorph = Duration(milliseconds: 360);

  /// Moving the selection indicator to the next item.
  static const Duration indicator = Duration(milliseconds: 380);
}
