// Geometry shared by the two renderers.

import 'package:flutter/widgets.dart';

import 'glass_typography.dart';

/// The measurements of the glass surfaces.
///
/// The fallback renderer lays itself out from these values directly; the native
/// renderer receives them through [toSpec] and lays itself out from the copy it
/// is given. Keeping a single source means a change moves both renderers
/// together.
///
/// The two padding helpers below exist for the native renderer, which is a bare
/// rectangle: the fallback applies its own padding (it contains the safe area
/// handling and the inner padding), so the Dart side has to pad the platform
/// view to the same numbers. If the two ever disagree, switching renderers
/// moves the glass.
abstract final class GlassMetrics {
  /// The horizontal distance from a bar to the edge of the page.
  static const double barEdge = 16;

  /// Vertical padding of a title bar, before the safe area is added.
  static const double titleBarTop = 8;
  static const double titleBarBottom = 8;

  /// Vertical padding above a capsule bar, before the safe area is added.
  static const double capsuleBarTop = 14;

  /// Vertical padding below a capsule bar. A floating capsule keeps more room
  /// when there is a safe area below it.
  static const double capsuleBarBottomSafe = 20;
  static const double capsuleBarBottom = 8;

  /// The diameter of a title bar item. Apple's floating glass control is 37.
  static const double titleChipHeight = 37;

  /// The gap between two adjacent title bar items.
  static const double titleChipSpacing = 6;

  /// Line heights of a large title and its subtitle.
  static const double titleLineHeight = 34;
  static const double subtitleLineHeight = 18;

  /// The gap between a subtitle and its title.
  static const double subtitleGap = 1;

  /// The share of the bar width a title may occupy, and the share the leading
  /// items may occupy, so that the two never overlap.
  static const double titleWidthFactor = 0.6;
  static const double leadingWidthFactor = 0.4;

  /// Horizontal inset of the two large title lines.
  static const double titleInlinePad = 8;

  /// The height of a capsule bar. A floating tab bar on iOS is about this tall.
  static const double capsuleHeight = 62;

  /// The gap between two adjacent capsule items.
  static const double capsuleItemSpacing = 2;

  /// The gap between the left and right capsules. The default of
  /// `GlassCapsuleBar.spacing`.
  static const double capsuleRightGap = 12;

  /// The smallest gap allowed between the two capsules once the right one has
  /// content.
  static const double capsuleRightMinGap = 8;

  /// The inset of the selection indicator inside a capsule item.
  static const double capsuleInset = 3;

  /// The capsule height the item metrics below were measured at, plus the range
  /// the content is allowed to scale over.
  static const double capsuleScaleBase = 52;
  static const double capsuleScaleMin = 0.9;
  static const double capsuleScaleMax = 1.4;

  /// The horizontal padding of a capsule item, measured at [capsuleScaleBase].
  ///
  /// The native indicator is 88 wide against 78 here, so the native item needs
  /// [capsuleItemPadDelta] less padding to reach the same width.
  static const double capsuleItemPad = 27;
  static const double capsuleItemPadNative = 22;
  static const double capsuleItemPadDelta =
      capsuleItemPad - capsuleItemPadNative;

  /// A capsule item is never narrower than this multiple of its height, so that
  /// the indicator keeps its shape.
  static const double capsuleItemMinWidthFactor = 1.2;

  /// How far the selection indicator stretches and shrinks as it moves, given
  /// as a fraction of the distance travelled and of its own height.
  static const double indicatorStretch = 0.18;
  static const double indicatorShrink = 0.06;

  /// The horizontal padding of a title bar item, with and without an icon, and
  /// the gap between its icon and its label.
  static const double titleItemPadWithIcon = 12;
  static const double titleItemPad = 14;
  static const double titleItemGap = 6;

  /// The size of the icon inside a title bar item.
  static const double titleItemIconSize = 18;

  /// The gap between the icon and the label of a capsule item.
  static const double capsuleIconGap = 1;

  /// The size of the badge dot in the top-right corner of an item, and its
  /// distance from that corner.
  static const double badgeSize = 8;
  static const double badgeInset = 3;

  /// The search row: leading padding, magnification icon size, and the gap
  /// between that icon and the text.
  static const double searchLeadingPad = 16;
  static const double searchIconSize = 22;
  static const double searchIconGap = 8;

  /// The size of a capsule item's icon, measured at [capsuleScaleBase] and
  /// multiplied by the scale when laid out.
  static const double capsuleIconSize = 22;

  /// Horizontal padding of the cancel action, in the title bar and in the
  /// capsule bar.
  static const double searchCancelPad = 14;
  static const double searchCancelPadTight = 12;

  /// Trailing padding of the search row, inside the edge of the glass.
  static const double searchTrailingPad = 14;

  /// The height of a bare glass surface when none is given.
  static const double surfaceFallbackHeight = 62;

  /// The metrics pushed to the native renderer.
  ///
  /// The native side derives none of its own dimensions: it receives this table
  /// so that a change here moves both renderers at once. Keys are the constant
  /// names above, so each value can be traced back to its source.
  static Map<String, Object?> toSpec() => <String, Object?>{
        'barEdge': barEdge,
        'titleBarTop': titleBarTop,
        'titleBarBottom': titleBarBottom,
        'capsuleBarTop': capsuleBarTop,
        'capsuleBarBottom': capsuleBarBottom,
        'capsuleBarBottomSafe': capsuleBarBottomSafe,
        'titleLineHeight': titleLineHeight,
        'subtitleLineHeight': subtitleLineHeight,
        'subtitleGap': subtitleGap,
        'capsuleInset': capsuleInset,
        'capsuleScaleBase': capsuleScaleBase,
        'capsuleScaleMin': capsuleScaleMin,
        'capsuleScaleMax': capsuleScaleMax,
        'capsuleItemPadNative': capsuleItemPadNative,
        'capsuleItemMinWidthFactor': capsuleItemMinWidthFactor,
        'capsuleItemSpacing': capsuleItemSpacing,
        'capsuleRightMinGap': capsuleRightMinGap,
        'capsuleIconSize': capsuleIconSize,
        'capsuleIconGap': capsuleIconGap,
        'titleItemIconSize': titleItemIconSize,
        'titleItemPad': titleItemPad,
        'titleItemPadWithIcon': titleItemPadWithIcon,
        'titleItemGap': titleItemGap,
        'badgeSize': badgeSize,
        'badgeInset': badgeInset,
        'searchLeadingPad': searchLeadingPad,
        'searchTrailingPad': searchTrailingPad,
        'searchIconSize': searchIconSize,
        'searchIconGap': searchIconGap,
        'searchCancelPad': searchCancelPad,
        'fontLargeTitle': GlassTypography.largeTitle,
        'fontTitle': GlassTypography.title,
        'fontSubtitle': GlassTypography.subtitle,
        'fontItem': GlassTypography.item,
        'fontCapsuleLabel': GlassTypography.capsuleLabel,
        'fontCapsuleLabelOnly': GlassTypography.capsuleLabelOnly,
        'fontLineHeight': GlassTypography.lineHeight,
      };
}

/// Padding for a title bar.
///
/// Matches the fallback title bar exactly: [GlassMetrics.barEdge] on the left
/// and right, [GlassMetrics.titleBarTop] / [GlassMetrics.titleBarBottom] above
/// and below, plus the safe area.
EdgeInsets titleBarPadding(BuildContext context) {
  final insets = MediaQuery.paddingOf(context);
  return EdgeInsets.fromLTRB(
    GlassMetrics.barEdge + insets.left,
    GlassMetrics.titleBarTop + insets.top,
    GlassMetrics.barEdge + insets.right,
    GlassMetrics.titleBarBottom,
  );
}

/// Padding for a capsule bar.
///
/// Matches the fallback capsule bar exactly: [GlassMetrics.barEdge] on the left
/// and right, [GlassMetrics.capsuleBarTop] above, and below either
/// [GlassMetrics.capsuleBarBottomSafe] or [GlassMetrics.capsuleBarBottom]
/// depending on whether there is a safe area, plus the safe area itself.
EdgeInsets capsuleBarPadding(BuildContext context) {
  final insets = MediaQuery.paddingOf(context);
  return EdgeInsets.fromLTRB(
    GlassMetrics.barEdge + insets.left,
    GlassMetrics.capsuleBarTop + insets.top,
    GlassMetrics.barEdge + insets.right,
    insets.bottom > 0
        ? GlassMetrics.capsuleBarBottomSafe
        : GlassMetrics.capsuleBarBottom,
  );
}
