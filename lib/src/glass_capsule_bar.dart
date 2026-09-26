// A floating capsule bar for the bottom of a page.

import 'package:flutter/material.dart';

import 'fallback/entrance_fade.dart';
import 'fallback/fallback_capsule_bar.dart';
import 'glass_icon.dart';
import 'glass_renderer.dart';
import 'native/glass_contract.dart';
import 'native/native_glass_view.dart';
import 'theme/glass_ink.dart';
import 'theme/glass_metrics.dart';

/// One item of a [GlassCapsuleBar].
///
/// Used by both [GlassCapsuleBar.items] and [GlassCapsuleBar.trailing].
@immutable
class GlassCapsuleItem {
  const GlassCapsuleItem({required this.label, this.icon, this.help});

  /// The label.
  final String label;

  /// The icon. Each renderer takes its own half of the pair; see [GlassIcon].
  final GlassIcon? icon;

  /// A tooltip shown on hover, on macOS. Equivalent to SwiftUI's `.help`.
  final String? help;

  @override
  bool operator ==(Object other) =>
      other is GlassCapsuleItem &&
      other.label == label &&
      other.icon == icon &&
      other.help == help;

  @override
  int get hashCode => Object.hash(label, icon, help);
}

/// A floating capsule bar, intended for the bottom of a page.
///
/// The bar is made of two separate capsules. The left one holds [items] and
/// draws a solid plate under the selected item; the right one holds [trailing],
/// or a magnifier when [searchEnabled] is set. When there is nothing on the
/// right, the left capsule is centred.
///
/// Search state is owned by the caller, in the same way as for
/// [GlassTitleBar.searching]: activating the magnifier reports
/// [onSearchEnter] and the caller sets [searching] to true, at which point the
/// left capsule widens into a text field with a cancel action and the right one
/// collapses. Tapping cancel reports [onSearchCancel] and the caller clears it.
///
/// The bar occupies [height] for the capsules, plus the padding applied around
/// them. Place it in a [Stack] to float it over content, or in a [Column] to
/// give it a row of its own.
class GlassCapsuleBar extends StatefulWidget {
  const GlassCapsuleBar({
    super.key,
    this.items = const <GlassCapsuleItem>[],
    this.selectedIndex,
    this.onItemTap,
    this.searchEnabled = false,
    this.searching = false,
    this.searchText,
    this.searchPrompt = 'Search',
    this.searchCancelLabel = 'Cancel',
    this.onSearchChanged,
    this.onSearchSubmitted,
    this.onSearchEnter,
    this.onSearchCancel,
    this.trailing,
    this.onTrailingTap,
    this.spacing = GlassMetrics.capsuleRightGap,
    this.height = GlassMetrics.capsuleHeight,
    this.visualWeight = 1.0,
    this.allowsHitTesting = true,
  })  : assert(
          selectedIndex == null || selectedIndex >= 0,
          'selectedIndex must not be negative.',
        ),
        assert(
          visualWeight >= 0 && visualWeight <= 1,
          'visualWeight must be between 0 and 1.',
        );

  /// The items held by the left capsule.
  final List<GlassCapsuleItem> items;

  /// The index of the selected item, or null when nothing is selected.
  final int? selectedIndex;

  /// Called with the index, into [items], of an activated item.
  final ValueChanged<int>? onItemTap;

  /// Whether the right end shows a magnifier, which reports [onSearchEnter].
  final bool searchEnabled;

  /// Whether search is currently active. Owned by the caller, in the same way
  /// as [GlassTitleBar.searching].
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

  /// The magnifier was activated. Setting [searching] is the caller's job.
  final VoidCallback? onSearchEnter;

  /// The search was cancelled. Clearing [searching] is the caller's job.
  final VoidCallback? onSearchCancel;

  /// The item held by the right capsule. It sizes to its label, or is circular
  /// when it has an icon only.
  final GlassCapsuleItem? trailing;

  /// Called when the right capsule is activated.
  final VoidCallback? onTrailingTap;

  /// The gap between the two capsules.
  final double spacing;

  /// The height of the capsules.
  final double height;

  /// Visual weight, 0–1. Both renderers use it to adjust the ink and the
  /// presence of the bar.
  final double visualWeight;

  /// Whether the bar accepts input. Equivalent to SwiftUI's
  /// `.allowsHitTesting`.
  final bool allowsHitTesting;

  @override
  State<GlassCapsuleBar> createState() => _GlassCapsuleBarState();
}

class _GlassCapsuleBarState extends State<GlassCapsuleBar> {
  void _onEvent(GlassEvent event) {
    switch (event.type) {
      case GlassEventType.itemTap:
        final index = event.index;
        if (index != null) widget.onItemTap?.call(index);
      case GlassEventType.trailingTap:
        widget.onTrailingTap?.call();
      case GlassEventType.searchEnter:
        widget.onSearchEnter?.call();
      case GlassEventType.searchChanged:
        final text = event.text;
        if (text != null) widget.onSearchChanged?.call(text);
      case GlassEventType.searchSubmitted:
        final text = event.text;
        if (text != null) widget.onSearchSubmitted?.call(text);
      case GlassEventType.searchCancel:
        widget.onSearchCancel?.call();
    }
  }

  Map<String, Object?> _spec(BuildContext context) {
    final ink = GlassInk.of(context, widget.visualWeight);
    final index = widget.selectedIndex;
    final trailing = widget.trailing;
    return <String, Object?>{
      'height': widget.height,
      'visualWeight': widget.visualWeight,
      'interactive': widget.allowsHitTesting,
      'items': <Object?>[for (final item in widget.items) _itemSpec(item)],
      if (index != null) 'selectedIndex': index,
      'searchEnabled': widget.searchEnabled,
      'searching': widget.searching,
      'spacing': widget.spacing,
      'searchHint': widget.searchPrompt,
      'searchCancel': widget.searchCancelLabel,
      if (trailing != null) 'trailing': _itemSpec(trailing),
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
      padding: capsuleBarPadding(context),
      child: SizedBox(
        height: widget.height,
        child: NativeGlassView(
          viewType: GlassContract.capsuleBarViewType,
          spec: _spec(context),
          onEvent: _onEvent,
        ),
      ),
    );
  }

  Widget _flutterBar() {
    final trailing = widget.trailing;
    // The fallback paints in the same frame as the content while the native view
    // arrives a frame late, so the fade is what makes the two appear alike. See
    // [EntranceFade].
    return EntranceFade(
      child: FallbackCapsuleBar(
        items: <FallbackCapsuleBarItem>[
          for (final item in widget.items)
            FallbackCapsuleBarItem(
              label: item.label,
              icon: item.icon?.fallback,
              help: item.help,
            ),
        ],
        selectedIndex: widget.selectedIndex,
        onItemTap: widget.onItemTap,
        searchEnabled: widget.searchEnabled,
        searching: widget.searching,
        spacing: widget.spacing,
        searchText: widget.searchText,
        searchPrompt: widget.searchPrompt,
        searchCancelLabel: widget.searchCancelLabel,
        onSearchChanged: widget.onSearchChanged,
        onSearchSubmitted: widget.onSearchSubmitted,
        onSearchEnter: widget.onSearchEnter,
        onSearchCancel: widget.onSearchCancel,
        trailing: trailing == null
            ? null
            : FallbackCapsuleBarItem(
                label: trailing.label,
                icon: trailing.icon?.fallback,
                help: trailing.help,
              ),
        height: widget.height,
        visualWeight: widget.visualWeight,
        allowsHitTesting: widget.allowsHitTesting,
        onTrailingTap: widget.onTrailingTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => usesNativeRenderer(
        GlassRendererScope.of(context),
      )
          ? _nativeBar()
          : _flutterBar();
}

/// One item, as the native renderer receives it. The native side only knows SF
/// Symbol names, so a Flutter icon is dropped.
Map<String, Object?> _itemSpec(GlassCapsuleItem item) => <String, Object?>{
      'label': item.label,
      if (item.icon?.systemName != null) 'symbol': item.icon!.systemName,
      if (item.help != null) 'tooltip': item.help,
    };
