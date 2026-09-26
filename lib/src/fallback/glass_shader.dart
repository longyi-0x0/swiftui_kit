// Loads the fragment program that draws the edge refraction.

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// The fragment program used for the glass edge refraction.
///
/// [ui.ImageFilter.shader] is only available on Impeller, so [isSupported] is
/// false elsewhere and callers fall back to a surface without refraction.
class GlassShader {
  GlassShader._();

  /// The asset key of the program.
  ///
  /// Assets of a package are addressed with a `packages/<name>/` prefix from the
  /// depending application, so the in-package path does not resolve.
  static const assetKey = 'packages/swiftui_kit/shaders/liquid_glass.frag';

  static ui.FragmentProgram? _program;
  static Future<ui.FragmentProgram?>? _loading;
  static bool _failed = false;

  /// Whether [ui.ImageFilter.shader] can be used on this engine.
  static bool get isSupported => ui.ImageFilter.isShaderFilterSupported;

  /// Loads the program, returning null on failure. The result is cached.
  static Future<ui.FragmentProgram?> load() {
    if (_program != null) return SynchronousFuture(_program);
    if (_failed) return SynchronousFuture(null);
    return _loading ??= _doLoad();
  }

  static Future<ui.FragmentProgram?> _doLoad() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(assetKey);
      _program = program;
      return program;
    } catch (e, st) {
      _failed = true;
      debugPrint('GlassShader load failed: $e\n$st');
      return null;
    } finally {
      _loading = null;
    }
  }

  /// Creates a [ui.FragmentShader] for one surface. The caller owns it and must
  /// dispose of it.
  static ui.FragmentShader? createShader() {
    final program = _program;
    if (program == null || !isSupported) return null;
    try {
      return program.fragmentShader();
    } catch (e, st) {
      debugPrint('GlassShader create failed: $e\n$st');
      return null;
    }
  }

  /// Clears the cached state. For tests only.
  @visibleForTesting
  static void resetForTest() {
    _program = null;
    _loading = null;
    _failed = false;
  }
}
