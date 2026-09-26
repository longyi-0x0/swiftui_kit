// One icon, described for both renderers.

import 'package:flutter/widgets.dart';

/// The icon of a [GlassCapsuleItem] or a [GlassTitleItem].
///
/// The two renderers do not accept the same kind of icon: the native one draws
/// the glyphs itself and therefore only accepts an SF Symbol name, while the
/// fallback one uses Flutter's [IconData]. A [GlassIcon] therefore carries one
/// of each.
///
/// Supply both to get the same icon from either renderer. Supplying only one
/// leaves the other renderer with the label alone.
@immutable
class GlassIcon {
  const GlassIcon({this.systemName, this.fallback})
      : assert(
          systemName != null || fallback != null,
          'An icon needs at least one of systemName or fallback.',
        );

  /// An icon identified only by its SF Symbol name.
  const GlassIcon.systemName(String systemName) : this(systemName: systemName);

  /// The SF Symbol name, such as `house.fill`. Used by the native renderer.
  final String? systemName;

  /// The Flutter icon. Used by the fallback renderer.
  final IconData? fallback;

  @override
  bool operator ==(Object other) =>
      other is GlassIcon &&
      other.systemName == systemName &&
      other.fallback == fallback;

  @override
  int get hashCode => Object.hash(systemName, fallback);

  @override
  String toString() =>
      'GlassIcon(systemName: $systemName, fallback: $fallback)';
}
