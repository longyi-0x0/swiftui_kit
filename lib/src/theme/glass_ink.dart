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

  /// 选中盘面的底色。
  ///
  /// 盘面不是系统组件画的：系统 TabView 的选中材质没有公开接口，这一套是 kit 自己铺的
  /// 一个 capsule 填充。系统那块是半透明材质，自己取样底下的内容，所以同一处在不同底上
  /// 的差值并不一样 —— 官方电话栏上量到过 11~20 级（栏 `#FDFDFD`、盘面
  /// `#E9E9EA`~`#F2F2F2`），另一张底上是 24 级（栏 `#F0F0F0`、盘面 `#D8D9DB`）。写死一个
  /// alpha 追不上它，只能落在这一段里：取 7%，在本应用的纸面上落在 15 级上下。
  ///
  /// 另外，系统那块盘面还带上浅下深的竖向渐变（上 245、下 233）。这里是一块平填充，
  /// 那条渐变没有仿。
  static const Color _plateLight = Color(0x12000000);
  static const Color _plateDark = Color(0x14FFFFFF);

  Color get selectedPlate {
    final Color base = isDark ? _plateDark : _plateLight;
    return base.withValues(alpha: base.a * (0.55 + 0.45 * _weight));
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
  /// flag, everything else as an ARGB integer except [subtitleAlpha]. The
  /// selected plate travels as a fill: the system's own glass cannot produce it,
  /// because over a flat page refraction shifts the tone by single digits.
  Map<String, Object?> toSpec() => <String, Object?>{
        'isDark': isDark,
        'foreground': foreground.toARGB32(),
        'selectedInk': item(selected: true).toARGB32(),
        'plainInk': item(selected: false).toARGB32(),
        'selectedPlate': selectedPlate.toARGB32(),
        'hint': hint.toARGB32(),
        'action': action.toARGB32(),
        'separator': separator.toARGB32(),
        'subtitleAlpha': subtitleAlpha,
      };
}
