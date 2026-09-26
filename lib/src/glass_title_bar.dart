// A floating title bar for the top of a page.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'fallback/entrance_fade.dart';
import 'fallback/fallback_title_bar.dart';
import 'glass_icon.dart';
import 'glass_renderer.dart';
import 'native/glass_contract.dart';
import 'native/native_glass_view.dart';
import 'theme/glass_ink.dart';
import 'theme/glass_metrics.dart';

/// Where an element of a [GlassTitleBar] sits.
///
/// Mirrors SwiftUI's `ToolbarItemPlacement`.
enum GlassTitlePlacement {
  /// The leading end. `.topBarLeading`.
  topBarLeading,

  /// The title position, mutually exclusive with [GlassTitleBar.title].
  /// `.principal`.
  principal,

  /// The trailing end, and the default for a [GlassTitleItem].
  /// `.topBarTrailing`.
  topBarTrailing,
}

/// How the title of a [GlassTitleBar] is displayed.
///
/// Mirrors SwiftUI's `navigationBarTitleDisplayMode`.
enum GlassTitleDisplayMode {
  /// A single small line, centred.
  inline,

  /// A large title aligned to the leading edge, which may carry a subtitle.
  large,
}

/// Something on the bar: either one item, or several items sharing one piece of
/// glass.
///
/// Mirrors SwiftUI's `ToolbarItem` / `ToolbarItemGroup` pair. Both kinds may be
/// mixed freely in [GlassTitleBar.items].
@immutable
sealed class GlassTitleElement {
  const GlassTitleElement();

  /// Where this element sits.
  GlassTitlePlacement get placement;
}

/// One item of a [GlassTitleBar].
///
/// At least one of [label] and [icon] must be given: an icon alone makes a
/// circular item, a label makes one that extends to the width of the text. The
/// native renderer additionally needs an SF Symbol; see [GlassIcon].
final class GlassTitleItem extends GlassTitleElement {
  @override
  final GlassTitlePlacement placement;

  const GlassTitleItem({
    this.placement = GlassTitlePlacement.topBarTrailing,
    this.label,
    this.icon,
    this.onPressed,
    this.help,
    this.badge = false,
    this.badgeColor,
    this.selected = false,
    this.tint,
  }) : assert(
          label != null || icon != null,
          'An item needs at least one of label or icon.',
        );

  /// The label.
  final String? label;

  /// The icon. See [GlassIcon].
  final GlassIcon? icon;

  /// Called when the item is activated. Null makes the item inert, which is
  /// useful for read-only displays.
  final VoidCallback? onPressed;

  /// A tooltip shown on hover, on macOS. Equivalent to SwiftUI's `.help`.
  final String? help;

  /// Whether to draw a badge dot in the top-right corner. Equivalent to
  /// SwiftUI's `.badge`.
  final bool badge;

  /// The badge colour. Defaults to the theme's error colour.
  final Color? badgeColor;

  /// Whether the item is selected.
  final bool selected;

  /// The fill used while selected. Defaults to the theme's primary colour.
  /// Equivalent to SwiftUI's `.tint`.
  final Color? tint;
}

/// Several items sharing one piece of glass.
///
/// Adjacent items each get their own glass, separated by
/// [GlassTitleBar.spacing]; items in a group share one, with [gap] inside.
/// Equivalent to SwiftUI's `ToolbarItemGroup`.
@immutable
final class GlassTitleGroup extends GlassTitleElement {
  const GlassTitleGroup({
    this.placement = GlassTitlePlacement.topBarTrailing,
    required this.items,
    this.gap = 2,
  }) : assert(items.length > 1, 'A group needs at least two items.');

  @override
  final GlassTitlePlacement placement;

  /// The items in the group, left to right.
  final List<GlassTitleItem> items;

  /// The gap between two items of the group.
  final double gap;
}

/// A floating glass bar, intended for the top of a page.
///
/// One item is one piece of glass; the title itself is text floating over the
/// page and carries no glass of its own. The layout follows SwiftUI's toolbar:
/// [items] are distributed by their [GlassTitleElement.placement], and
/// [title] fills the principal position.
///
/// Search state is owned by the caller: the magnifier is one of the [items], and
/// its `onPressed` sets [searching] to true, at which point the centre becomes a
/// text field and the trailing end becomes a cancel action. Tapping cancel
/// reports [onSearchCancel], and the caller clears [searching].
///
/// There is no dedicated back button: it is simply the leading item, written
/// like any other.
///
/// An item can only contain a label and an icon. The glass of one renderer is
/// drawn by the system and of the other by this package, so an arbitrary widget
/// cannot cross to the native side; put such widgets on the page itself instead.
class GlassTitleBar extends StatefulWidget {
  const GlassTitleBar({
    super.key,
    this.title,
    this.subtitle,
    this.displayMode = GlassTitleDisplayMode.inline,
    this.largeTitleColor,
    this.items = const <GlassTitleElement>[],
    this.searching = false,
    this.searchText,
    this.searchPrompt = 'Search',
    this.searchCancelLabel = 'Cancel',
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

  /// The title. Displayed centred when inline, and large and leading-aligned
  /// when [displayMode] is [GlassTitleDisplayMode.large].
  final String? title;

  /// The subtitle. Shown only alongside a large title, on the line above it.
  final String? subtitle;

  /// How the title is displayed.
  final GlassTitleDisplayMode displayMode;

  /// The colour of a large title. Defaults to the ink colour; use white when
  /// the bar sits over a photograph.
  final Color? largeTitleColor;

  /// The items on the bar. [GlassTitleItem] and [GlassTitleGroup] may be mixed.
  final List<GlassTitleElement> items;

  /// Whether search is currently active. Owned by the caller.
  final bool searching;

  /// The search text. When supplied it is owned by the caller, which can read
  /// and clear it. Otherwise the glass keeps its own.
  final TextEditingController? searchText;

  /// Placeholder of the search field. Equivalent to SwiftUI's
  /// `.searchable(prompt:)`.
  final String searchPrompt;

  /// Label of the cancel action shown while searching.
  final String searchCancelLabel;

  /// The search text changed.
  final ValueChanged<String>? onSearchChanged;

  /// The search text was submitted.
  final ValueChanged<String>? onSearchSubmitted;

  /// The search was cancelled. Clearing [searching] is the caller's job.
  final VoidCallback? onSearchCancel;

  /// The size of one item, which is the diameter when it is circular.
  final double height;

  /// The gap between two adjacent items that are not in the same group.
  final double spacing;

  /// Visual weight, 0–1.
  final double visualWeight;

  /// Whether the bar accepts input. Equivalent to SwiftUI's
  /// `.allowsHitTesting`.
  final bool allowsHitTesting;

  @override
  State<GlassTitleBar> createState() => _GlassTitleBarState();
}

class _GlassTitleBarState extends State<GlassTitleBar> {
  static const double _subtitleLine = GlassMetrics.subtitleLineHeight;
  static const double _titleLine = GlassMetrics.titleLineHeight;

  /// The height of the content box.
  ///
  /// A large title needs room for its subtitle plus the title itself, matching
  /// the fallback renderer's large-title row: a 34 pt title and a 15 pt
  /// subtitle, both at a line height of one.
  double get _contentHeight => switch (widget.displayMode) {
        GlassTitleDisplayMode.inline => widget.height,
        GlassTitleDisplayMode.large => math.max(
            widget.height,
            (widget.subtitle == null ? 0 : _subtitleLine) + _titleLine,
          ),
      };

  void _onEvent(GlassEvent event) {
    switch (event.type) {
      case GlassEventType.itemTap:
        // The index refers to the flattened list, with groups expanded, which
        // is how the native side numbers them too.
        final index = event.index;
        final flat = _flatItems;
        if (index != null && index >= 0 && index < flat.length) {
          flat[index].onPressed?.call();
        }
      case GlassEventType.searchChanged:
        final text = event.text;
        if (text != null) widget.onSearchChanged?.call(text);
      case GlassEventType.searchSubmitted:
        final text = event.text;
        if (text != null) widget.onSearchSubmitted?.call(text);
      case GlassEventType.searchCancel:
        widget.onSearchCancel?.call();
      case GlassEventType.trailingTap:
      case GlassEventType.searchEnter:
        // This bar never reports these two: search is entered by the caller.
        break;
    }
  }

  /// Every item in order, with groups expanded. Event indices refer to this
  /// list.
  List<GlassTitleItem> get _flatItems => <GlassTitleItem>[
        for (final element in widget.items)
          if (element is GlassTitleGroup)
            ...element.items
          else
            element as GlassTitleItem,
      ];

  Map<String, Object?> _spec(BuildContext context) {
    final ink = GlassInk.of(context, widget.visualWeight);
    final scheme = Theme.of(context).colorScheme;
    final largeTitleColor = widget.largeTitleColor;
    return <String, Object?>{
      if (widget.title != null) 'title': widget.title,
      if (widget.subtitle != null) 'subtitle': widget.subtitle,
      'displayMode': widget.displayMode == GlassTitleDisplayMode.large
          ? 'large'
          : 'inline',
      if (largeTitleColor != null)
        'largeTitleColor': largeTitleColor.toARGB32(),
      'items': <Object?>[
        for (final element in widget.items) _elementSpec(element, ink, scheme),
      ],
      'searching': widget.searching,
      if (widget.searchText != null) 'searchText': widget.searchText!.text,
      'searchHint': widget.searchPrompt,
      'searchCancel': widget.searchCancelLabel,
      'height': widget.height,
      'spacing': widget.spacing,
      'visualWeight': widget.visualWeight,
      'interactive': widget.allowsHitTesting,
      'palette': ink.toSpec(),
      'metrics': GlassMetrics.toSpec(),
    };
  }

  Widget _nativeBar() {
    assert(
      GlassRendererScope.of(context) != GlassRenderer.native ||
          hasNativeRenderer,
      'GlassRenderer.native requires a platform with the native renderer '
      '(iOS or macOS).',
    );
    return Padding(
      padding: titleBarPadding(context),
      child: SizedBox(
        height: _contentHeight,
        child: NativeGlassView(
          viewType: GlassContract.titleBarViewType,
          spec: _spec(context),
          onEvent: _onEvent,
        ),
      ),
    );
  }

  /// The fallback paints in the same frame as the content while the native view
  /// arrives a frame late, so the fade is what makes the two appear alike. See
  /// [EntranceFade].
  Widget _flutterBar() => EntranceFade(
        child: FallbackTitleBar(
          title: widget.title,
          subtitle: widget.subtitle,
          displayMode: switch (widget.displayMode) {
            GlassTitleDisplayMode.inline => FallbackTitleBarDisplayMode.inline,
            GlassTitleDisplayMode.large => FallbackTitleBarDisplayMode.large,
          },
          largeTitleColor: widget.largeTitleColor,
          items: <FallbackTitleBarItem>[
            for (final element in widget.items)
              if (element is GlassTitleGroup)
                FallbackTitleBarItem.group(
                  placement: _placement(element.placement),
                  gap: element.gap,
                  members: <FallbackTitleBarItem>[
                    for (final item in element.items) _flutterItem(item),
                  ],
                )
              else
                _flutterItem(element as GlassTitleItem),
          ],
          searching: widget.searching,
          searchText: widget.searchText,
          searchPrompt: widget.searchPrompt,
          searchCancelLabel: widget.searchCancelLabel,
          onSearchChanged: widget.onSearchChanged,
          onSearchSubmitted: widget.onSearchSubmitted,
          onSearchCancel: widget.onSearchCancel,
          height: widget.height,
          spacing: widget.spacing,
          visualWeight: widget.visualWeight,
          allowsHitTesting: widget.allowsHitTesting,
        ),
      );

  @override
  Widget build(BuildContext context) => usesNativeRenderer(
        GlassRendererScope.of(context),
      )
          ? _nativeBar()
          : _flutterBar();
}

/// One item, converted for the fallback renderer.
FallbackTitleBarItem _flutterItem(GlassTitleItem item) => FallbackTitleBarItem(
      placement: _placement(item.placement),
      icon: item.icon?.fallback,
      label: item.label,
      onPressed: item.onPressed,
      help: item.help,
      badge: item.badge,
      badgeColor: item.badgeColor,
      selected: item.selected,
      tint: item.tint,
    );

FallbackTitleBarPlacement _placement(GlassTitlePlacement placement) =>
    switch (placement) {
      GlassTitlePlacement.topBarLeading =>
        FallbackTitleBarPlacement.topBarLeading,
      GlassTitlePlacement.principal => FallbackTitleBarPlacement.principal,
      GlassTitlePlacement.topBarTrailing =>
        FallbackTitleBarPlacement.topBarTrailing,
    };

/// One element, as the native renderer receives it.
///
/// A single item is one entry; a group adds a `group` list, whose members are
/// numbered as if flattened.
Map<String, Object?> _elementSpec(
  GlassTitleElement element,
  GlassInk ink,
  ColorScheme scheme,
) {
  if (element is GlassTitleGroup) {
    return <String, Object?>{
      'placement': _placementName(element.placement),
      'gap': element.gap,
      'group': <Object?>[
        for (final item in element.items) _itemSpec(item, ink, scheme),
      ],
    };
  }
  return _itemSpec(element as GlassTitleItem, ink, scheme);
}

String _placementName(GlassTitlePlacement placement) => switch (placement) {
      GlassTitlePlacement.topBarLeading => 'leading',
      GlassTitlePlacement.principal => 'principal',
      GlassTitlePlacement.topBarTrailing => 'trailing',
    };

/// One item, as the native renderer receives it.
///
/// The ink and the fill are resolved here, on the Dart side, matching what the
/// fallback renderer would pick: a selected item's label takes the colour the
/// theme pairs with the primary colour, or white when the item carries its own
/// [GlassTitleItem.tint], and its glass is filled with the primary colour or
/// with that tint.
Map<String, Object?> _itemSpec(
  GlassTitleItem item,
  GlassInk ink,
  ColorScheme scheme,
) {
  final selected = item.selected;
  final fill = item.tint ?? scheme.primary;
  final itemInk = selected
      ? (item.tint == null ? scheme.onPrimary : Colors.white)
      : ink.foreground;
  return <String, Object?>{
    'placement': _placementName(item.placement),
    if (item.label != null) 'label': item.label,
    if (item.icon?.systemName != null) 'symbol': item.icon!.systemName,
    'pressable': item.onPressed != null,
    if (item.help != null) 'tooltip': item.help,
    'dot': item.badge,
    'dotColor': (item.badgeColor ?? scheme.error).toARGB32(),
    'selected': selected,
    'ink': itemInk.toARGB32(),
    if (selected) 'tint': fill.toARGB32(),
  };
}
