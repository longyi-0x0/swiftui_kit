// The title bar as painted by the fallback renderer.

import 'package:flutter/material.dart';

import '../theme/glass_ink.dart';
import '../theme/glass_metrics.dart';
import '../theme/glass_motion.dart';
import '../theme/glass_typography.dart';
import 'glass_pressable.dart';
import 'glass_search_field.dart';
import 'liquid_glass_surface.dart';

/// Where an item of a [FallbackTitleBar] sits.
///
/// Mirrors SwiftUI's `ToolbarItemPlacement`.
enum FallbackTitleBarPlacement {
  /// The leading end. `.topBarLeading`.
  topBarLeading,

  /// The title position, which swaps with the title itself. `.principal`.
  principal,

  /// The trailing end, and the default. `.topBarTrailing`.
  topBarTrailing,
}

/// How the title of a [FallbackTitleBar] is displayed.
///
/// Mirrors SwiftUI's `navigationBarTitleDisplayMode`.
enum FallbackTitleBarDisplayMode {
  /// One small line, centred, `.inline`.
  inline,

  /// A large title aligned to the leading edge, which may carry a subtitle,
  /// `.large`.
  large,
}

/// One item of a [FallbackTitleBar]. Equivalent to SwiftUI's `ToolbarItem`.
///
/// At least one of [icon] and [label] is required:
///
/// - [icon] alone makes a circular item that fills the height.
/// - [label] alone, or both, makes an item as wide as its content, with the
///   icon to the left of the label.
///
/// Use [FallbackTitleBarItem.group] when several items should share one piece of
/// glass.
class FallbackTitleBarItem {
  /// Where the item sits.
  final FallbackTitleBarPlacement placement;

  /// The icon.
  final IconData? icon;

  /// The label.
  final String? label;

  /// The items sharing this item's glass. Set only by
  /// [FallbackTitleBarItem.group].
  ///
  /// When present the item is treated as a container and [icon] and [label] are
  /// unused.
  final List<FallbackTitleBarItem>? members;

  /// The gap between the members of a group.
  final double gap;

  /// Called when the item is activated. Null makes the item inert, which is
  /// useful for read-only displays.
  final VoidCallback? onPressed;

  /// A tooltip shown on hover, on macOS.
  final String? help;

  /// Whether to draw a badge dot in the top-right corner, for signals that the
  /// label cannot express.
  final bool badge;

  /// The badge colour. Defaults to the theme's error colour.
  final Color? badgeColor;

  /// Whether the item is selected, which fills its glass.
  final bool selected;

  /// The fill used while selected. Defaults to the theme's primary colour; set
  /// it to match a colour from somewhere else.
  final Color? tint;

  const FallbackTitleBarItem({
    this.placement = FallbackTitleBarPlacement.topBarTrailing,
    this.icon,
    this.label,
    this.onPressed,
    this.help,
    this.badge = false,
    this.badgeColor,
    this.selected = false,
    this.tint,
  })  : members = null,
        gap = 0,
        assert(
          icon != null || label != null,
          'An item needs at least one of icon or label.',
        );

  /// Several items sharing one piece of glass. Equivalent to SwiftUI's
  /// `ToolbarItemGroup`.
  ///
  /// Given their own glass, adjacent items are separated by
  /// [FallbackTitleBar.spacing]. Grouped, only the outside is an edge and the
  /// members are separated by [gap].
  const FallbackTitleBarItem.group({
    this.placement = FallbackTitleBarPlacement.topBarTrailing,
    required List<FallbackTitleBarItem> this.members,
    this.gap = 2,
    this.onPressed,
    this.help,
    this.badge = false,
    this.badgeColor,
    this.selected = false,
    this.tint,
  })  : icon = null,
        label = null,
        assert(members.length > 1, 'A group needs at least two items.');

  /// Whether this item is a group of items sharing one glass.
  bool get isGroup => members != null;
}

/// The title bar.
///
/// The bar is not a plate: each of the [items] is its own piece of floating
/// glass, and the title is text laid over the content with no glass of its own.
/// Content passes underneath. Where the bar is placed, and therefore how much
/// padding it carries, is up to the caller: a [Stack], or the first row of a
/// [Column].
///
/// The layout follows SwiftUI's toolbar: an item is a
/// `ToolbarItem(placement:)` and the title is a `navigationTitle`, which is
/// displayed large and leading-aligned when [displayMode] is
/// [FallbackTitleBarDisplayMode.large].
///
/// - [items] are distributed by their placement. Each has its own glass,
///   separated by [spacing].
/// - [searching] is owned by the caller. Entering search replaces the centre
///   with a text field and the trailing items with a cancel action; there is a
///   field even when the bar has no title.
///
/// The leading end takes at most [GlassMetrics.leadingWidthFactor] of the width
/// and the title at most [GlassMetrics.titleWidthFactor], so the two never
/// overlap. A long label shrinks rather than overflowing.
class FallbackTitleBar extends StatefulWidget {
  const FallbackTitleBar({
    super.key,
    this.title,
    this.subtitle,
    this.displayMode = FallbackTitleBarDisplayMode.inline,
    this.largeTitleColor,
    this.items = const <FallbackTitleBarItem>[],
    this.searching = false,
    this.searchText,
    required this.searchPrompt,
    required this.searchCancelLabel,
    this.onSearchChanged,
    this.onSearchSubmitted,
    this.onSearchCancel,
    this.height = GlassMetrics.titleChipHeight,
    this.spacing = GlassMetrics.titleChipSpacing,
    this.visualWeight = 1.0,
    this.allowsHitTesting = true,
  }) : assert(
          visualWeight >= 0 && visualWeight <= 1,
          'visualWeight must be between 0 and 1.',
        );

  /// The title. Centred when inline, and large and leading-aligned when
  /// [displayMode] is [FallbackTitleBarDisplayMode.large]. Equivalent to
  /// SwiftUI's `navigationTitle`.
  final String? title;

  /// A line of detail below a large title, such as "502 items".
  final String? subtitle;

  /// How the title is displayed.
  final FallbackTitleBarDisplayMode displayMode;

  /// The colour of a large title. Defaults to the ink colour; set it when the
  /// bar sits over a photograph.
  final Color? largeTitleColor;

  /// The items on the bar, in order.
  final List<FallbackTitleBarItem> items;

  /// Whether search is currently active. Owned by the caller.
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

  /// Search was cancelled. Clearing [searching] is the caller's job.
  final VoidCallback? onSearchCancel;

  /// The height of one item, which is the diameter when it is circular.
  final double height;

  /// The gap between two adjacent items that are not in the same group.
  final double spacing;

  /// Visual weight, 0–1.
  final double visualWeight;

  /// Whether the bar accepts input.
  final bool allowsHitTesting;

  @override
  State<FallbackTitleBar> createState() => _FallbackTitleBarState();
}

class _FallbackTitleBarState extends State<FallbackTitleBar>
    with SingleTickerProviderStateMixin {
  /// Used when the caller supplies no controller of its own.
  final TextEditingController _ownSearchText = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  TextEditingController get _searchText => widget.searchText ?? _ownSearchText;
  late final AnimationController _morph;

  @override
  void initState() {
    super.initState();
    _morph = AnimationController(vsync: this, duration: GlassMotion.titleMorph);
    if (widget.searching) {
      _morph.value = 1;
      _focusSearch();
    }
  }

  @override
  void didUpdateWidget(covariant FallbackTitleBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searching == oldWidget.searching) return;
    if (widget.searching) {
      _morph.forward(from: 0);
      _focusSearch();
    } else {
      _searchText.clear();
      _searchFocusNode.unfocus();
      _morph.reverse();
    }
  }

  @override
  void dispose() {
    _ownSearchText.dispose();
    _searchFocusNode.dispose();
    _morph.dispose();
    super.dispose();
  }

  /// Focus is requested after the field has been laid out.
  void _focusSearch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  double get _weight => widget.visualWeight.clamp(0.0, 1.0);

  GlassInk get _ink => GlassInk.of(context, _weight);

  /// The glass around one item. Without a width it sizes to its content.
  ///
  /// This is the same glass as an unselected capsule item: no extra fill and no
  /// separate rim, because an item is not a different material, only the same
  /// glass at a smaller size. Giving it a solid fill would make it read 45
  /// levels brighter than the capsule over a backing such as a photograph.
  Widget _chip(Widget child, {bool expand = false}) {
    return LiquidGlassSurface(
      height: widget.height,
      expand: expand,
      // An item starts from a circle; a narrower content box is still never
      // smaller than that.
      child: expand
          ? child
          : ConstrainedBox(
              constraints: BoxConstraints(minWidth: widget.height),
              child: child,
            ),
    );
  }

  /// The item in the principal position, if any.
  FallbackTitleBarItem? get _principal {
    for (final each in widget.items) {
      if (each.placement == FallbackTitleBarPlacement.principal) return each;
    }
    return null;
  }

  /// The items at one placement, in the order they were given.
  List<FallbackTitleBarItem> _at(FallbackTitleBarPlacement placement) =>
      widget.items.where((each) => each.placement == placement).toList();

  @override
  Widget build(BuildContext context) {
    assert(
      widget.title == null || _principal == null,
      'Provide either title or a principal item, not both.',
    );

    final ink = _ink;
    final bar = SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          GlassMetrics.barEdge,
          GlassMetrics.titleBarTop,
          GlassMetrics.barEdge,
          GlassMetrics.titleBarBottom,
        ),
        child: BackdropGroup(
          child: LayoutBuilder(
            builder: (context, constraints) => AnimatedBuilder(
              // Entering search re-dresses the whole bar, so the whole bar is
              // driven by _morph.
              animation: _morph,
              builder: (context, _) {
                final t = GlassMotion.ease.transform(_morph.value);
                final searching = widget.searching || t > 0;
                return switch (widget.displayMode) {
                  _ when searching => _buildSearchRow(
                      constraints.maxWidth,
                      t,
                      ink,
                    ),
                  FallbackTitleBarDisplayMode.inline => _buildInlineRow(
                      ink,
                      constraints.maxWidth,
                    ),
                  FallbackTitleBarDisplayMode.large => _buildLargeRow(ink),
                };
              },
            ),
          ),
        ),
      ),
    );

    return IgnorePointer(ignoring: !widget.allowsHitTesting, child: bar);
  }

  /// A run of items. Each gets its own glass, separated by [spacing]; an item
  /// built by [FallbackTitleBarItem.group] shares one glass among its members,
  /// separated only by the group's own gap.
  Widget? _buildItems(List<FallbackTitleBarItem> items, GlassInk ink) {
    if (items.isEmpty) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < items.length; i++) ...<Widget>[
          if (i > 0) SizedBox(width: widget.spacing),
          // A long item shrinks into the space that is left rather than
          // overflowing.
          Flexible(
            child: _chip(
              items[i].isGroup
                  ? _buildGroupBody(items[i], ink)
                  : _buildItemBody(items[i], ink),
            ),
          ),
        ],
      ],
    );
  }

  /// The content of a group: several items inside one glass, separated only by
  /// the group's gap.
  ///
  /// Individually the members would each be a circle or would size to their own
  /// label, and those outlines and paddings are redundant once they share a
  /// glass, so a member contributes only its content. The outside is left to the
  /// shared glass.
  Widget _buildGroupBody(FallbackTitleBarItem group, GlassInk ink) {
    final members = group.members!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < members.length; i++) ...<Widget>[
          if (i > 0) SizedBox(width: group.gap),
          _buildItemBody(members[i], ink, bare: true),
        ],
      ],
    );
  }

  /// The leading items.
  Widget? _buildLeading(GlassInk ink) =>
      _buildItems(_at(FallbackTitleBarPlacement.topBarLeading), ink);

  /// The title, which is text and never a piece of glass.
  Widget _buildTitle(GlassInk ink, {bool large = false}) {
    final principal = _principal;
    if (principal != null) {
      final content = _plainLabel(principal.label!, ink);
      if (large) return content;
      final onPressed = principal.onPressed;
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: GlassMetrics.titleInlinePad,
        ),
        child: onPressed == null
            ? content
            : GlassPressable(
                onPressed: onPressed,
                help: principal.help,
                child: content,
              ),
      );
    }

    final title = widget.title;
    if (title == null) return const SizedBox.shrink();
    return _plainLabel(title, ink, large: large);
  }

  Widget _plainLabel(String text, GlassInk ink, {bool large = false}) {
    final color =
        large ? (widget.largeTitleColor ?? ink.foreground) : ink.foreground;
    final style = large
        ? TextStyle(
            fontSize: GlassTypography.largeTitle,
            fontWeight: GlassTypography.largeTitleWeight,
            color: color,
            letterSpacing: GlassTypography.largeTitleLetterSpacing,
            height: GlassTypography.lineHeight,
            leadingDistribution: TextLeadingDistribution.even,
          )
        : TextStyle(
            fontSize: GlassTypography.title,
            fontWeight: GlassTypography.titleWeight,
            color: color,
          );
    return Padding(
      padding: large
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(
              horizontal: GlassMetrics.titleInlinePad,
            ),
      child: Text(
        text,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textHeightBehavior: large
            ? const TextHeightBehavior(
                applyHeightToFirstAscent: false,
                applyHeightToLastDescent: false,
              )
            : null,
      ),
    );
  }

  /// The search state: a field in the centre and a cancel action at the trailing
  /// end.
  Widget _buildSearchRow(double maxWidth, double t, GlassInk ink) =>
      _buildRow(ink, maxWidth, t, center: _buildCenter(ink, t));

  /// The inline state: leading items, trailing items, and the title centred.
  ///
  /// A trailing item keeps its own width while the leading end takes at most
  /// [GlassMetrics.leadingWidthFactor] of the width, so on a narrow bar the
  /// labels shrink. The title is kept inside
  /// [GlassMetrics.titleWidthFactor] so that it cannot collide with the leading
  /// end.
  Widget _buildInlineRow(GlassInk ink, double maxWidth) => _buildRow(
        ink,
        maxWidth,
        0,
        center: _buildTitle(ink),
        centerIsTitle: true,
      );

  /// The large state: a large leading-aligned title with the items beside it.
  Widget _buildLargeRow(GlassInk ink) {
    final leading = _buildLeading(ink);
    final trailing = _buildTrailing(ink, 0);
    // The top of the title is aligned with the top of the items, which is how
    // the native layout looks.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (leading != null) ...[leading, SizedBox(width: widget.spacing)],
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildTitle(ink, large: true),
              if (widget.subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: GlassMetrics.subtitleGap),
                  child: Text(
                    widget.subtitle!,
                    style: TextStyle(
                      fontSize: GlassTypography.subtitle,
                      fontWeight: GlassTypography.subtitleWeight,
                      color: widget.largeTitleColor?.withValues(
                        alpha: GlassInk.subtitleAlpha,
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) ...[SizedBox(width: widget.spacing), trailing],
      ],
    );
  }

  /// The skeleton of a row: one leading slot, one centre, one trailing slot.
  ///
  /// With [centerIsTitle] the centre is overlaid on the centre of the bar so
  /// that the title is not pushed off centre by the widths of the ends. A search
  /// field instead stretches to fill what is left.
  Widget _buildRow(
    GlassInk ink,
    double maxWidth,
    double t, {
    required Widget center,
    bool centerIsTitle = false,
  }) {
    final leading = _buildLeading(ink);
    final trailing = _buildTrailing(ink, t);

    final leftAndRight = <Widget>[
      if (leading != null)
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth * GlassMetrics.leadingWidthFactor,
            ),
            child: leading,
          ),
        )
      else
        // With nothing at the leading end the trailing item still has to stay
        // against the edge.
        const Spacer(),
      if (trailing != null) ...[
        if (leading != null) SizedBox(width: widget.spacing),
        trailing,
      ],
    ];

    if (!centerIsTitle) {
      return Row(
        children: <Widget>[
          if (leading != null) ...[
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth * GlassMetrics.leadingWidthFactor,
              ),
              child: leading,
            ),
            SizedBox(width: widget.spacing),
          ],
          Expanded(child: center),
          if (trailing != null) ...[
            SizedBox(width: widget.spacing),
            trailing,
          ],
        ],
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: leftAndRight,
        ),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth * GlassMetrics.titleWidthFactor,
          ),
          child: center,
        ),
      ],
    );
  }

  /// The centre. While search is being entered or left, the title and the field
  /// swap places.
  Widget _buildCenter(GlassInk ink, double t) {
    final title = _buildTitle(ink);
    if (t == 0 && !widget.searching) return title;
    // The title leaves during the first half and the field arrives during the
    // second, in both directions.
    if (t > 0.5) {
      return Opacity(
        opacity: ((t - 0.5) * 2).clamp(0.0, 1.0),
        child: _chip(
          GlassSearchField(
            controller: _searchText,
            focusNode: _searchFocusNode,
            ink: ink,
            prompt: widget.searchPrompt,
            cancelLabel: widget.searchCancelLabel,
            onChanged: widget.onSearchChanged,
            onSubmitted: widget.onSearchSubmitted,
          ),
          expand: true,
        ),
      );
    }
    return Opacity(opacity: (1 - t * 2).clamp(0.0, 1.0), child: title);
  }

  /// The trailing slot. In search the items withdraw to give the field its
  /// width, and a cancel action appears in their place.
  Widget? _buildTrailing(GlassInk ink, double t) {
    final items = _at(FallbackTitleBarPlacement.topBarTrailing);
    if (items.isEmpty && !widget.searching && _morph.value == 0) return null;

    final group = _buildItems(items, ink) ?? const SizedBox.shrink();
    if (t == 0 && !widget.searching) return group;

    // The items leave during the first half and cancel arrives during the
    // second, on the same schedule as the title swap.
    if (t > 0.5) {
      return Opacity(
        opacity: ((t - 0.5) * 2).clamp(0.0, 1.0),
        child: _buildCancel(ink),
      );
    }
    return Opacity(opacity: (1 - t * 2).clamp(0.0, 1.0), child: group);
  }

  Widget _buildCancel(GlassInk ink) => GlassSearchCancel(
        ink: ink,
        onPressed: widget.onSearchCancel,
        label: widget.searchCancelLabel,
        height: widget.height,
      );

  /// The content of one item. The glass around it is supplied by the caller.
  ///
  /// [bare] is for a member of a group: it must not add a circular frame of its
  /// own, because the group's shared glass already provides the outside and
  /// further circles inside would add another ring.
  Widget _buildItemBody(
    FallbackTitleBarItem item,
    GlassInk ink, {
    bool bare = false,
  }) {
    final theme = Theme.of(context);
    final selected = item.selected;
    final fill = item.tint ?? theme.colorScheme.primary;
    final color = selected
        ? (item.tint == null ? theme.colorScheme.onPrimary : Colors.white)
        : ink.foreground;
    const iconSize = GlassMetrics.titleItemIconSize;
    final label = item.label;
    final icon = item.icon;

    Widget child;
    if (label == null) {
      child = Center(child: Icon(icon, size: iconSize, color: color));
    } else {
      child = Center(
        widthFactor: 1,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: icon == null
                ? GlassMetrics.titleItemPad
                : GlassMetrics.titleItemPadWithIcon,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: iconSize, color: color),
                const SizedBox(width: GlassMetrics.titleItemGap),
              ],
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: GlassTypography.item,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (selected) {
      // A selected item is filled. The rim and the specular highlight of the
      // glass stay on top of the fill, which reads as coloured glass.
      child = DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(widget.height / 2),
        ),
        child: child,
      );
    } else if (bare) {
      // A member of a group: the outside comes from the shared glass, so this
      // item only stands on its own content, filling the height.
      child = SizedBox(
        height: widget.height,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: GlassMetrics.titleItemPadWithIcon / 2,
          ),
          child: child,
        ),
      );
    } else if (label == null) {
      // A lone icon-only item is a circle, and the tappable area fills the
      // height.
      child = SizedBox(
        width: widget.height,
        height: widget.height,
        child: child,
      );
    }

    if (item.badge) {
      child = Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          child,
          Positioned(
            top: GlassMetrics.badgeInset,
            right: GlassMetrics.badgeInset,
            child: _Badge(color: item.badgeColor ?? theme.colorScheme.error),
          ),
        ],
      );
    }

    final onPressed = item.onPressed;
    if (onPressed == null) return child;
    return GlassPressable(
      onPressed: onPressed,
      help: item.help,
      child: child,
    );
  }
}

/// The badge dot, used to flag something that needs attention.
class _Badge extends StatelessWidget {
  const _Badge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: const SizedBox(
          width: GlassMetrics.badgeSize,
          height: GlassMetrics.badgeSize,
        ),
      );
}
