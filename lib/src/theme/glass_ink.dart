// Foreground colours for the glass.

import 'package:flutter/material.dart';

/// The colours of the text and icons drawn on the glass.
///
/// Colours are resolved on the Dart side and pushed to the native renderer
/// as-is: the native side never inspects the brightness or the theme, it only
/// draws the values it is given. That keeps the ink identical across the two
/// renderers.
///
/// [weight] expresses visual weight on a 0–1 scale: 1 for a surface in the
/// foreground, 0 for one that has receded behind, say, a modal.
class GlassInk {
  const GlassInk({
    required this.isDark,
    required this.primary,
    required this.weight,
  });

  /// Reads the current [Theme] and pairs it with [weight].
  factory GlassInk.of(BuildContext context, double weight) {
    final theme = Theme.of(context);
    return GlassInk(
      isDark: theme.brightness == Brightness.dark,
      primary: theme.colorScheme.primary,
      weight: weight.clamp(0.0, 1.0),
    );
  }

  /// The brightness of the surrounding theme.
  ///
  /// The native renderer uses this to pick the appearance of its view — the
  /// system glass follows the system appearance, so without this a dark system
  /// would put dark ink on dark glass.
  final bool isDark;

  /// The theme's primary colour, used by the selection indicator and the cancel
  /// action.
  final Color primary;

  /// Visual weight, 0–1.
  final double weight;

  /// How much of its alpha the subtitle of a large title keeps.
  ///
  /// Shared with the native renderer, which applies it to its own subtitle.
  static const double subtitleAlpha = 0.75;

  /// The visual weight above which a selected caption is drawn bold. Bolding it
  /// while the surface has receded only makes it stand out more.
  static const double emphasisThreshold = 0.85;

  double get _weight => weight.clamp(0.0, 1.0);

  /// The colour of icons and of a title.
  Color get foreground {
    if (isDark) {
      return Color.lerp(
        Colors.white.withValues(alpha: 0.55),
        Colors.white,
        _weight,
      )!;
    }
    return Color.lerp(
      const Color(0xFF3A3A3C),
      const Color(0xFF1C1C1E),
      _weight,
    )!;
  }

  /// The label colour of a capsule item. In light mode the selected item takes
  /// the theme's primary colour.
  Color item({required bool selected}) {
    if (isDark) {
      final focusedSelected = Colors.white;
      final focusedUnselected = Colors.white.withValues(alpha: 0.75);
      final unfocusedSelected = Colors.white.withValues(alpha: 0.75);
      final unfocusedUnselected = Colors.white.withValues(alpha: 0.45);
      if (selected) {
        return Color.lerp(unfocusedSelected, focusedSelected, _weight)!;
      }
      return Color.lerp(unfocusedUnselected, focusedUnselected, _weight)!;
    }

    const focusedUnselected = Color(0xFF000000);
    const unfocusedSelected = Color(0xFF3A3A3C);
    const unfocusedUnselected = Color(0xFF636366);
    if (selected) {
      return Color.lerp(unfocusedSelected, primary, _weight)!;
    }
    return Color.lerp(unfocusedUnselected, focusedUnselected, _weight)!;
  }

  /// The fill behind the selected capsule item: a solid, light-coloured plate.
  Color get selectedFill {
    final focused = isDark
        ? Colors.white.withValues(alpha: 0.22)
        : Colors.white.withValues(alpha: 0.94);
    final unfocused = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.55);
    return Color.lerp(unfocused, focused, _weight)!;
  }

  /// Placeholder text, such as the hint of a search field.
  Color get hint =>
      isDark ? Colors.white.withValues(alpha: 0.45) : const Color(0xFF8E8E93);

  /// The colour of an action that leans on the theme colour, such as cancel.
  Color get action => Color.lerp(hint, primary, _weight)!;

  /// A separator inside a glass surface.
  Color get separator => isDark
      ? Colors.white.withValues(alpha: 0.14)
      : Colors.black.withValues(alpha: 0.08);

  /// The palette pushed to the native renderer.
  ///
  /// The keys match the Swift `GlassPalette` initialiser; `isDark` travels as a
  /// flag, everything else as an ARGB integer except [subtitleAlpha].
  Map<String, Object?> toSpec() => <String, Object?>{
        'isDark': isDark,
        'foreground': foreground.toARGB32(),
        'selectedInk': item(selected: true).toARGB32(),
        'plainInk': item(selected: false).toARGB32(),
        'selectedFill': selectedFill.toARGB32(),
        'hint': hint.toARGB32(),
        'action': action.toARGB32(),
        'separator': separator.toARGB32(),
        'subtitleAlpha': subtitleAlpha,
      };
}
