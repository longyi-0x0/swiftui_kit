// Which of the two renderers draws the glass.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The renderer that draws the glass.
///
/// A renderer is either the *native* one, which hosts the system SwiftUI view in
/// a platform view, or the *fallback* one, which paints the glass in Flutter.
/// Both consume the same spec, so they are interchangeable apart from the glass
/// itself.
enum GlassRenderer {
  /// Use the native renderer where it is available and the fallback elsewhere.
  /// This is the default.
  auto,

  /// Always use the native renderer. Asserts if the platform has none.
  native,

  /// Always paint the glass in Flutter.
  fallback,
}

/// Whether this platform has a native renderer.
///
/// iOS and macOS do. Web does not, because it has no platform views. Tests can
/// make this true by setting `debugDefaultTargetPlatformOverride`.
bool get hasNativeRenderer =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

/// Whether [renderer] resolves to the native renderer on this platform.
bool usesNativeRenderer(GlassRenderer renderer) => switch (renderer) {
      GlassRenderer.auto => hasNativeRenderer,
      GlassRenderer.native => true,
      GlassRenderer.fallback => false,
    };

/// Overrides the renderer for the subtree it wraps.
///
/// The override is placed on an enclosing widget rather than on each bar,
/// because which renderer a page uses is a page-level decision. Without an
/// enclosing [GlassRendererScope] the renderer is [GlassRenderer.auto].
class GlassRendererScope extends InheritedWidget {
  const GlassRendererScope({
    super.key,
    required this.renderer,
    required super.child,
  });

  /// The renderer used by this subtree.
  final GlassRenderer renderer;

  /// The renderer for this subtree, or [GlassRenderer.auto] when there is no
  /// enclosing [GlassRendererScope].
  static GlassRenderer of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<GlassRendererScope>()
          ?.renderer ??
      GlassRenderer.auto;

  @override
  bool updateShouldNotify(GlassRendererScope oldWidget) =>
      renderer != oldWidget.renderer;
}
