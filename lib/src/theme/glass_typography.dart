// Type scale shared by the glass surfaces.

import 'package:flutter/widgets.dart';

/// The type scale used on the glass.
///
/// The named sizes follow Apple's text styles (Large Title 34 / Headline 17 /
/// Subheadline 15) because that is what they were measured against. The two
/// capsule label sizes are not on that scale — they are smaller than Caption 2 —
/// so they are named after their role instead.
abstract final class GlassTypography {
  /// Large Title, used by a large title bar title.
  static const double largeTitle = 34;
  static const FontWeight largeTitleWeight = FontWeight.w700;
  static const double largeTitleLetterSpacing = 0.4;

  /// Headline. Used by an inline title, the search field, the cancel action and
  /// the label of a title bar item.
  static const double title = 17;
  static const FontWeight titleWeight = FontWeight.w600;

  /// Subheadline. Used by the subtitle of a large title bar.
  static const double subtitle = 15;
  static const FontWeight subtitleWeight = FontWeight.w500;

  /// The label of a title bar item that also has an icon.
  static const double item = 17;

  /// The label of a capsule item that also has an icon. Scaled by the capsule
  /// height before use.
  static const double capsuleLabel = 10;
  static const double capsuleLabelLetterSpacing = -0.08;

  /// The label of a capsule item without an icon.
  static const double capsuleLabelOnly = 13;
  static const double capsuleLabelOnlyLetterSpacing = -0.2;

  /// Line height is collapsed to one: these labels sit in a fixed-height
  /// surface, where extra leading would push them off centre.
  static const double lineHeight = 1.0;

  static const FontWeight capsuleLabelWeight = FontWeight.w500;
  static const FontWeight capsuleLabelWeightSelected = FontWeight.w600;
}
