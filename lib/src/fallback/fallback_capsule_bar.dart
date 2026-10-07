// The capsule bar as painted by the fallback renderer.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/glass_ink.dart';
import '../theme/glass_metrics.dart';
import '../theme/glass_motion.dart';
import '../theme/glass_typography.dart';
import 'glass_pressable.dart';
import 'glass_search_field.dart';
import 'liquid_glass_surface.dart';

/// One item of a [FallbackCapsuleBar].
class FallbackCapsuleBarItem {
  const FallbackCapsuleBarItem({required this.label, this.icon, this.help});

  /// The label. An empty label with an icon renders as an icon-only item.
  final String label;

  /// The icon.
  final IconData? icon;

  /// A tooltip shown on hover, on macOS.
  final String? help;
}

/// The capsule bar.
///
/// Two floating glass capsules sit at either end of a padded row, and the
/// selection is a solid plate that slides between items. When [searchEnabled] is
/// set, entering search widens the left capsule into a search row and shrinks
/// the right one away.
class FallbackCapsuleBar extends StatefulWidget {
  const FallbackCapsuleBar({
    super.key,
    this.items = const <FallbackCapsuleBarItem>[],
    this.selectedIndex,
    this.onItemTap,
    this.searchEnabled = false,
    this.searching = false,
    this.searchText,
    required this.searchPrompt,
    required this.searchCancelLabel,
    this.onSearchChanged,
    this.onSearchSubmitted,
    this.onSearchEnter,
    this.onSearchCancel,
    this.trailing,
    this.onTrailingTap,
    this.height = GlassMetrics.capsuleHeight,
    this.visualWeight = 1.0,
    this.allowsHitTesting = true,
    this.spacing = GlassMetrics.capsuleRightGap,
  });

  /// The items of the left capsule.
  final List<FallbackCapsuleBarItem> items;

  /// The index of the selected item, or null when nothing is selected.
  final int? selectedIndex;

  /// Called with the index of an activated item.
  final ValueChanged<int>? onItemTap;

  /// Whether the right end shows a magnifier.
  final bool searchEnabled;

  /// Whether search is currently active.
  final bool searching;

  /// The search text. When null the bar keeps a controller of its own, and
  /// clears it on leaving search either way.
  final TextEditingController? searchText;

  /// Placeholder of the search field.
  final String searchPrompt;

  /// Label of the cancel action.
  final String searchCancelLabel;

  /// The search text changed.
  final ValueChanged<String>? onSearchChanged;

  /// The search text was submitted.
  final ValueChanged<String>? onSearchSubmitted;

  /// The magnifier was activated. Entering search is the caller's job.
  final VoidCallback? onSearchEnter;

  /// Search was cancelled.
  final VoidCallback? onSearchCancel;

  /// The item of the right capsule.
  final FallbackCapsuleBarItem? trailing;

  /// Called when the right capsule is activated.
  final VoidCallback? onTrailingTap;

  /// The height of both capsules.
  final double height;

  /// Visual weight, 0–1.
  final double visualWeight;

  /// Whether the bar accepts input.
  final bool allowsHitTesting;

  /// The gap between the two capsules.
  final double spacing;

  @override
  State<FallbackCapsuleBar> createState() => _FallbackCapsuleBarState();
}

class _FallbackCapsuleBarState extends State<FallbackCapsuleBar>
    with TickerProviderStateMixin {
  /// Used when the caller supplies no controller of its own.
  final TextEditingController _ownSearchText = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  TextEditingController get _searchText => widget.searchText ?? _ownSearchText;

  late final AnimationController _indicatorController;
  late final AnimationController _searchMorphController;
  int? _fromIndex;
  int? _toIndex;

  @override
  void initState() {
    super.initState();
    _indicatorController = AnimationController(
      vsync: this,
      duration: GlassMotion.indicator,
    );
    _searchMorphController = AnimationController(
      vsync: this,
      duration: GlassMotion.capsuleMorph,
    );
    _toIndex = widget.selectedIndex;
    _fromIndex = widget.selectedIndex;
    _indicatorController.value = 1;
    if (widget.searching) {
      _searchMorphController.value = 1;
      _focusSearch();
    }
  }

  @override
  void didUpdateWidget(covariant FallbackCapsuleBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searching != oldWidget.searching) {
      if (widget.searching) {
        _searchMorphController.forward(from: 0);
        _focusSearch();
      } else {
        _searchText.clear();
        _searchFocusNode.unfocus();
        _searchMorphController.reverse();
      }
    }
    if (widget.selectedIndex != oldWidget.selectedIndex &&
        widget.selectedIndex != null) {
      _animateIndicatorTo(widget.selectedIndex!);
    }
  }

  @override
  void dispose() {
    _ownSearchText.dispose();
    _searchFocusNode.dispose();
    _indicatorController.dispose();
    _searchMorphController.dispose();
    super.dispose();
  }

  void _animateIndicatorTo(int index) {
    _fromIndex = _toIndex ?? index;
    _toIndex = index;
    _indicatorController
      ..value = 0
      ..forward();
  }

  /// The magnifier was activated. Entering search is the caller's job.
  void _requestSearch() => widget.onSearchEnter?.call();

  /// Focus is requested after the field has been laid out.
  void _focusSearch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  bool get _hasRightSlot {
    if (widget.searching) return true;
    if (widget.searchEnabled) return true;
    return widget.trailing != null;
  }

  double get _weight => widget.visualWeight.clamp(0.0, 1.0);

  GlassInk get _ink => GlassInk.of(context, _weight);

  void _onItemTap(int index) => widget.onItemTap?.call(index);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomPad = bottomInset > 0
        ? GlassMetrics.capsuleBarBottomSafe
        : GlassMetrics.capsuleBarBottom;

    final bar = SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          GlassMetrics.barEdge,
          GlassMetrics.capsuleBarTop,
          GlassMetrics.barEdge,
          bottomPad,
        ),
        child: BackdropGroup(
          child: widget.searchEnabled ? _buildMorphingBar() : _buildNormalBar(),
        ),
      ),
    );

    return IgnorePointer(ignoring: !widget.allowsHitTesting, child: bar);
  }

  /// With search enabled: the left capsule widens to the full width while the
  /// right one shrinks and fades away.
  Widget _buildMorphingBar() {
    return AnimatedBuilder(
      animation: _searchMorphController,
      builder: (context, _) {
        final t = GlassMotion.ease.transform(_searchMorphController.value);
        final searching = widget.searching || t > 0;

        if (!searching) {
          return _buildNormalBar();
        }

        final rightScale = (1.0 - t).clamp(0.0, 1.0);
        return Row(
          children: [
            Expanded(
              child: t > 0.5
                  ? _buildSearchCapsule(cancelOpacity: t)
                  : LiquidGlassSurface(
                      height: widget.height,
                      expand: true,
                      child: Padding(
                        padding: const EdgeInsets.all(
                          GlassMetrics.capsuleInset,
                        ),
                        child: _buildLeftContent(),
                      ),
                    ),
            ),
            if (rightScale > 0.01) ...[
              SizedBox(width: widget.spacing * rightScale),
              Opacity(
                opacity: rightScale,
                child: Transform.scale(
                  scale: 0.85 + 0.15 * rightScale,
                  child: LiquidGlassSurface(
                    height: widget.height,
                    circular: true,
                    child: IconButton(
                      icon: Icon(Icons.search, color: _ink.foreground),
                      onPressed: _requestSearch,
                      tooltip: widget.searchPrompt,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildNormalBar() {
    final left = LiquidGlassSurface(
      height: widget.height,
      // Inset by 3 on all sides; the items and the indicator align to the
      // resulting inner box.
      //
      // Measured on the native indicator in a 62 pt frame: 56 tall and inset by
      // 3.0 on the top, bottom and left. With an inset of 3 the inner box is
      // 62 - 6 = 56, which the indicator fills exactly.
      child: Padding(
        padding: const EdgeInsets.all(GlassMetrics.capsuleInset),
        child: _buildLeftContent(),
      ),
    );

    if (!_hasRightSlot) {
      return Row(children: [const Spacer(), left, const Spacer()]);
    }

    final right = _buildRightGlass();
    return Row(children: [left, const Spacer(), if (right != null) right]);
  }

  Widget _buildSearchCapsule({required double cancelOpacity}) {
    return LiquidGlassSurface(
      height: widget.height,
      expand: true,
      child: GlassSearchField(
        controller: _searchText,
        focusNode: _searchFocusNode,
        ink: _ink,
        prompt: widget.searchPrompt,
        cancelLabel: widget.searchCancelLabel,
        onChanged: widget.onSearchChanged,
        onSubmitted: widget.onSearchSubmitted,
        onCancel: widget.onSearchCancel,
        cancelOpacity: cancelOpacity,
      ),
    );
  }

  Widget? _buildRightGlass() {
    if (widget.searchEnabled) {
      return LiquidGlassSurface(
        height: widget.height,
        circular: true,
        child: IconButton(
          icon: Icon(Icons.search, color: _ink.foreground),
          onPressed: _requestSearch,
          tooltip: widget.searchPrompt,
        ),
      );
    }

    final trailing = widget.trailing;
    if (trailing == null) return null;

    final glass = LiquidGlassSurface(
      height: widget.height,
      circular: true,
      child: Center(child: _buildItemContent(trailing)),
    );

    final onTrailingTap = widget.onTrailingTap;
    if (onTrailingTap == null) return glass;

    return GestureDetector(
      onTap: onTrailingTap,
      behavior: HitTestBehavior.opaque,
      child: glass,
    );
  }

  /// The inner height of the glass, inset by [GlassMetrics.capsuleInset] on all
  /// sides — the gap between the native selection pill and the outer edge.
  double get _innerHeight => widget.height - GlassMetrics.capsuleInset * 2;

  /// Width and padding scale with the height, relative to the 52 pt design
  /// height.
  double get _layoutScale =>
      (widget.height / GlassMetrics.capsuleScaleBase).clamp(
        GlassMetrics.capsuleScaleMin,
        GlassMetrics.capsuleScaleMax,
      );

  Widget _buildLeftContent() {
    // The native indicator is 88 wide for the same items at the same height,
    // against 78 here, so each side of an item carries 5 pt more padding.
    final hPad = GlassMetrics.capsuleItemPad * _layoutScale;
    // Keep the indicator from becoming too tall and narrow: the minimum width
    // follows the height.
    final itemMinWidth = widget.height * GlassMetrics.capsuleItemMinWidthFactor;
    return _SlidingIndicatorRow(
      itemCount: widget.items.length,
      selectedIndex: widget.selectedIndex,
      fromIndex: _fromIndex,
      toIndex: _toIndex,
      animation: _indicatorController,
      curve: GlassMotion.ease,
      indicatorColor: _ink.selectedPlate,
      height: _innerHeight,
      itemBuilder: (context, i) {
        final selected = widget.selectedIndex == i;
        return GlassPressable(
          onPressed: () => _onItemTap(i),
          help: widget.items[i].help,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: itemMinWidth),
            child: SizedBox(
              height: _innerHeight,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Center(
                  child: _buildItemContent(
                    widget.items[i],
                    selected: selected,
                    fontWeight: selected && _weight > GlassInk.emphasisThreshold
                        ? GlassTypography.capsuleLabelWeightSelected
                        : GlassTypography.capsuleLabelWeight,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// A label with the line height collapsed to one.
  ///
  /// The label lives in a box of fixed height, where extra leading would push it
  /// off centre. The strut has to use the same values, or the label and the icon
  /// end up misaligned.
  Widget _label(
    String text,
    double size,
    double tracking,
    FontWeight fontWeight,
    Color color, {
    TextAlign? align,
  }) =>
      Text(
        text,
        style: TextStyle(
          fontSize: size,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: tracking,
          height: GlassTypography.lineHeight,
        ),
        strutStyle: StrutStyle(
          fontSize: size,
          height: GlassTypography.lineHeight,
          forceStrutHeight: true,
        ),
        textAlign: align,
      );

  Widget _buildItemContent(
    FallbackCapsuleBarItem item, {
    bool selected = false,
    FontWeight fontWeight = GlassTypography.capsuleLabelWeight,
  }) {
    final color = _ink.item(selected: selected);
    // At the 52 pt design height the icon is 22 and the label 10, so the
    // proportions hold as the height changes.
    final scale = _layoutScale;
    final iconSize = GlassMetrics.capsuleIconSize * scale;
    final labelSize = GlassTypography.capsuleLabel * scale;

    if (item.label.isEmpty && item.icon != null) {
      return Icon(item.icon, size: iconSize, color: color);
    }

    if (item.icon == null) {
      final textSize = GlassTypography.capsuleLabelOnly * scale;
      return _label(
        item.label,
        textSize,
        GlassTypography.capsuleLabelOnlyLetterSpacing,
        fontWeight,
        color,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: iconSize,
          width: iconSize,
          child: Icon(item.icon, size: iconSize, color: color),
        ),
        SizedBox(height: GlassMetrics.capsuleIconGap * scale),
        _label(
          item.label,
          labelSize,
          GlassTypography.capsuleLabelLetterSpacing,
          fontWeight,
          color,
          align: TextAlign.center,
        ),
      ],
    );
  }
}

/// The row that carries the selection plate and slides it between items,
/// stretching it along the way.
class _SlidingIndicatorRow extends StatefulWidget {
  const _SlidingIndicatorRow({
    required this.itemCount,
    required this.selectedIndex,
    required this.fromIndex,
    required this.toIndex,
    required this.animation,
    required this.curve,
    required this.indicatorColor,
    required this.height,
    required this.itemBuilder,
  });

  final int itemCount;
  final int? selectedIndex;
  final int? fromIndex;
  final int? toIndex;
  final Animation<double> animation;
  final Curve curve;
  final Color indicatorColor;
  final double height;
  final IndexedWidgetBuilder itemBuilder;

  @override
  State<_SlidingIndicatorRow> createState() => _SlidingIndicatorRowState();
}

class _SlidingIndicatorRowState extends State<_SlidingIndicatorRow> {
  late List<GlobalKey> _itemKeys;
  final List<Rect> _itemRects = [];

  @override
  void initState() {
    super.initState();
    _itemKeys = List.generate(widget.itemCount, (_) => GlobalKey());
    widget.animation.addListener(_onTick);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didUpdateWidget(covariant _SlidingIndicatorRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemCount != widget.itemCount) {
      _itemKeys = List.generate(widget.itemCount, (_) => GlobalKey());
    }
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation.removeListener(_onTick);
      widget.animation.addListener(_onTick);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void dispose() {
    widget.animation.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  void _measure() {
    if (!mounted) return;
    final rowBox = context.findRenderObject() as RenderBox?;
    if (rowBox == null || !rowBox.hasSize) return;

    final next = <Rect>[];
    for (final key in _itemKeys) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final topLeft = rowBox.globalToLocal(box.localToGlobal(Offset.zero));
      next.add(topLeft & box.size);
    }
    setState(() {
      _itemRects
        ..clear()
        ..addAll(next);
    });
  }

  Rect? _indicatorRect() {
    if (_itemRects.isEmpty) return null;
    final fromIdx = widget.fromIndex;
    final toIdx = widget.toIndex ?? widget.selectedIndex;
    final from =
        (fromIdx != null && fromIdx >= 0 && fromIdx < _itemRects.length)
            ? _itemRects[fromIdx]
            : null;
    final to = (toIdx != null && toIdx >= 0 && toIdx < _itemRects.length)
        ? _itemRects[toIdx]
        : null;

    if (from != null && to != null) {
      final t = widget.curve.transform(widget.animation.value);
      final base = Rect.lerp(from, to, t)!;
      final distance = (to.center.dx - from.center.dx).abs();
      final stretch = math.sin(math.pi * t);
      final extraW = distance * GlassMetrics.indicatorStretch * stretch;
      final shrinkH = GlassMetrics.indicatorShrink * base.height * stretch;
      return Rect.fromCenter(
        center: base.center,
        width: base.width + extraW,
        height: math.max(0.0, base.height - shrinkH),
      );
    }
    return to ?? from;
  }

  @override
  Widget build(BuildContext context) {
    final indicator = _indicatorRect();

    return SizedBox(
      height: widget.height,
      child: Stack(
        alignment: Alignment.centerLeft,
        clipBehavior: Clip.none,
        children: [
          if (indicator != null)
            Positioned(
              left: indicator.left,
              top: indicator.top,
              width: indicator.width,
              height: indicator.height,
              child: _IndicatorPill(
                color: widget.indicatorColor,
                // The corner radius follows the height of the plate itself.
                height: indicator.height,
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.itemCount; i++) ...[
                if (i > 0)
                  const SizedBox(width: GlassMetrics.capsuleItemSpacing),
                KeyedSubtree(
                  key: _itemKeys[i],
                  child: widget.itemBuilder(context, i),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _IndicatorPill extends StatelessWidget {
  const _IndicatorPill({required this.color, required this.height});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);
    // A flat plate: no stroke and no shadow.
    //
    // Scanning the native plate for the same spec row by row shows a uniform
    // white across it, with no bright line along the edge and no darkening
    // below. Both were ours, and the shadow read as a grey band under the
    // bottom edge.
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: color,
        shape: RoundedSuperellipseBorder(borderRadius: radius),
      ),
    );
  }
}
