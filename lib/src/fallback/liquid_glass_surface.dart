// The translucent surface the fallback renderer paints.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/glass_material.dart';
import '../theme/glass_metrics.dart';
import '../theme/glass_motion.dart';
import 'glass_shader.dart';

/// A translucent surface in the style of the system's liquid glass.
///
/// The surface is a frosted backdrop, lifted or darkened according to the
/// backing, with a lit rim and a hairline around it. Where the engine supports
/// it, a refraction shader is composed on top.
///
/// The width comes from one of three places: [circular] makes it match the
/// height, [width] uses that value, and [expand] fills the parent. With none of
/// them the surface sizes to its child.
class LiquidGlassSurface extends StatefulWidget {
  const LiquidGlassSurface({
    super.key,
    required this.child,
    this.height,
    this.width,
    this.expand = false,
    this.circular = false,
    this.blurSigma = GlassMaterial.blur,
    this.backgroundColor,
    this.borderRadius,
    this.enableRefraction = true,
    this.rimStrength = 1.0,
  });

  /// The content drawn on the glass.
  final Widget child;

  /// The height of the surface. Defaults to
  /// [GlassMetrics.surfaceFallbackHeight].
  final double? height;

  /// The width of the surface, unless [circular] or [expand] applies.
  final double? width;

  /// Whether the surface fills the available width.
  final bool expand;

  /// Whether the surface is a circle of diameter [height].
  final bool circular;

  /// The blur radius of the backdrop.
  final double blurSigma;

  /// A colour to tint the glass with, instead of the default body colour.
  final Color? backgroundColor;

  /// An explicit corner radius. Defaults to a fully rounded shape.
  final BorderRadius? borderRadius;

  /// Whether to compose the refraction shader, where the engine supports it.
  final bool enableRefraction;

  /// Strength of the rim, where 1 is the default and 0 removes it.
  final double rimStrength;

  @override
  State<LiquidGlassSurface> createState() => _LiquidGlassSurfaceState();
}

class _LiquidGlassSurfaceState extends State<LiquidGlassSurface> {
  ui.FragmentShader? _shader;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _prepareShader();
  }

  @override
  void didUpdateWidget(covariant LiquidGlassSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enableRefraction != widget.enableRefraction &&
        widget.enableRefraction &&
        _shader == null) {
      _prepareShader();
    }
  }

  Future<void> _prepareShader() async {
    if (!_composeRefractionOverBlur ||
        !widget.enableRefraction ||
        !GlassShader.isSupported) {
      if (mounted) setState(() => _ready = true);
      return;
    }
    await GlassShader.load();
    if (!mounted) return;
    _shader?.dispose();
    _shader = GlassShader.createShader();
    setState(() => _ready = true);
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  BorderRadius _resolveRadius(double height) {
    if (widget.borderRadius != null) return widget.borderRadius!;
    return BorderRadius.circular(height / 2);
  }

  /// The float is carried by the rim, not by the shadow: the shadow only falls a
  /// little way below. Spreading a glow outwards reads as a lit sign rather than
  /// as glass.
  List<BoxShadow> _shadows() => <BoxShadow>[
        // In screenshots of the system glass the backing darkens by only about 8
        // levels directly below it. A heavier or wider shadow makes neighbouring
        // surfaces merge into one dark block.
        BoxShadow(
          color: Colors.black.withValues(
            alpha: _isDark
                ? GlassMaterial.shadowAlphaNearDark
                : GlassMaterial.shadowAlphaNearLight,
          ),
          blurRadius: GlassMaterial.shadowBlurNear,
          offset: GlassMaterial.shadowOffsetNear,
          spreadRadius: GlassMaterial.shadowSpreadNear,
        ),
        BoxShadow(
          color: Colors.black.withValues(
            alpha: _isDark
                ? GlassMaterial.shadowAlphaFarDark
                : GlassMaterial.shadowAlphaFarLight,
          ),
          blurRadius: GlassMaterial.shadowBlurFar,
          offset: GlassMaterial.shadowOffsetFar,
          spreadRadius: GlassMaterial.shadowSpreadFar,
        ),
      ];

  /// 是否把折射 shader 叠在 blur 外面。
  ///
  /// `ImageFilter.compose(shader ∘ blur)` 在带 Clip 时会打乱 `FlutterFragCoord` /
  /// UV（flutter/flutter#181660），把远处像素采进表面 —— 二楼顶上的绿书就会出现在
  /// 底部胶囊里。引擎修好之前关掉叠法，只保留模糊霜化。
  static const bool _composeRefractionOverBlur = false;

  /// Whether the shader is already painting the body, in which case this layer
  /// must not paint it again.
  bool get _shaderPaintsBody =>
      _composeRefractionOverBlur &&
      _ready &&
      _shader != null &&
      widget.enableRefraction &&
      GlassShader.isSupported;

  /// The flat colour of the body.
  ///
  /// The native glass is a single flat tone — sampling the same spec top and
  /// bottom gives the same value — so this is a flat fill with no vertical
  /// gradient.
  Color _tint() {
    // The shader computes the body into the background layer already, lifting it
    // along the measured curve, so this layer steps aside.
    if (_shaderPaintsBody) return const Color(0x00000000);
    final body = glassBody(_isDark);
    final base = widget.backgroundColor;
    if (base != null) {
      return base.withValues(alpha: body.opacity);
    }
    return body.color.withValues(alpha: body.opacity);
  }

  static ColorFilter _saturate(double s) {
    final inv = 1.0 - s;
    const r = 0.2126;
    const g = 0.7152;
    const b = 0.0722;
    return ColorFilter.matrix(<double>[
      inv * r + s, inv * g, inv * b, 0, 0, //
      inv * r, inv * g + s, inv * b, 0, 0, //
      inv * r, inv * g, inv * b + s, 0, 0, //
      0, 0, 0, 1, 0,
    ]);
  }

  /// A slight lift, which produces the frosted look.
  static ColorFilter _brighten(double amount) {
    final a = amount.clamp(0.0, 1.0);
    return ColorFilter.matrix(<double>[
      1, 0, 0, 0, 255 * a, //
      0, 1, 0, 0, 255 * a, //
      0, 0, 1, 0, 255 * a, //
      0, 0, 0, 1, 0,
    ]);
  }

  ui.ImageFilter _baseFilter() {
    final blur = ui.ImageFilter.blur(
      sigmaX: widget.blurSigma,
      sigmaY: widget.blurSigma,
      tileMode: TileMode.clamp,
    );
    final tinted = ui.ImageFilter.compose(
      outer: _saturate(
        _isDark ? GlassMaterial.saturateDark : GlassMaterial.saturateLight,
      ),
      inner: blur,
    );
    if (_isDark) return tinted;
    return ui.ImageFilter.compose(
      outer: _brighten(GlassMaterial.brighten),
      inner: tinted,
    );
  }

  ui.ImageFilter _buildFilter(BorderRadius radius, double glassHeight) {
    final base = _baseFilter();
    final shader = _shader;
    if (!_composeRefractionOverBlur ||
        !_ready ||
        shader == null ||
        !widget.enableRefraction ||
        !GlassShader.isSupported) {
      return base;
    }

    // The corner radius comes from the height alone, not from the width, so a
    // surface sized to its content keeps the same shape.
    final corner = radius.topLeft.x.clamp(0.0, glassHeight / 2);
    // A wide, shallow refraction band: a narrow, strong one makes the edge look
    // as if a piece had been cut out of it.
    shader.setFloat(2, corner);
    shader.setFloat(3, GlassMaterial.refractionEdgeWidth);
    shader.setFloat(4, GlassMaterial.refractionAmount);
    shader.setFloat(5, GlassMaterial.refractionSpecular);

    // How the body lifts the background. Every surface uses the same tone: a
    // control and a capsule are not two different materials.
    final tone = glassTone(_isDark);
    shader.setFloat(6, tone.lift);
    shader.setFloat(7, tone.power);
    shader.setFloat(8, tone.gain);
    shader.setFloat(9, tone.floor);
    shader.setFloat(10, tone.chroma);

    try {
      final refraction = ui.ImageFilter.shader(shader);
      return ui.ImageFilter.compose(outer: refraction, inner: base);
    } catch (_) {
      return base;
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.height ?? GlassMetrics.surfaceFallbackHeight;
    final radius = _resolveRadius(height);
    final width = widget.circular ? height : widget.width;

    final frame = DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: _shadows()),
      child: ClipRSuperellipse(
        borderRadius: radius,
        child: BackdropFilter.grouped(
          filter: _buildFilter(radius, height),
          child: CustomPaint(
            // The rim is painted onto the background so that it does not land on
            // top of the content — a solid fill such as the selection plate
            // would otherwise pick up a dark edge below it. Measured against the
            // native plate, which stays flat white to its bottom edge, painting
            // the rim on top darkened ours by 23 levels.
            painter: _GlassRimPainter(
              borderRadius: radius,
              isDark: _isDark,
              strength: widget.rimStrength,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(borderRadius: radius, color: _tint()),
              child: widget.child,
            ),
          ),
        ),
      ),
    );

    // Only animate when the width is fixed. A surface sized to its content can
    // move between finite and infinite constraints, which cannot be animated.
    final Widget shell = width == null
        ? SizedBox(height: height, child: frame)
        : AnimatedContainer(
            duration: GlassMotion.width,
            curve: GlassMotion.shrink,
            height: height,
            width: width,
            child: frame,
          );

    if (widget.expand) {
      return SizedBox(width: double.infinity, child: shell);
    }
    return shell;
  }
}

/// The rim of the glass.
///
/// The system glass has no line at its edge. What marks the boundary is a soft
/// glow built up along the top edge and a thin darkening along the bottom, with
/// only the middle brighter than the backing. A hard line would read as a
/// bordered sign, so all three are laid down as blurred fills.
class _GlassRimPainter extends CustomPainter {
  _GlassRimPainter({
    required this.borderRadius,
    required this.isDark,
    this.strength = 1.0,
  });

  final BorderRadius borderRadius;
  final bool isDark;

  /// Strength of the rim, where 1 is the default and 0 removes it.
  final double strength;

  Path _path(Rect rect) =>
      RoundedSuperellipseBorder(borderRadius: borderRadius).getOuterPath(rect);

  /// How lit a rim segment is, given its outward normal.
  ///
  /// There are two lights, top-left and bottom-right. A normal pointing towards
  /// either is lit; one pointing elsewhere — bottom-left or top-right — is left
  /// almost dark. On a circle this produces two arcs: sampling the native
  /// circular control gives 224–229 on the top-left arc and 207–220 on the
  /// bottom-right one, while the other two arcs stay at the body tone, around
  /// 185. On an elongated capsule it produces two bands, one along the top edge
  /// and one along the bottom.
  double _lit(Offset n) {
    const double k = 2.0;
    final double a = n.dx * GlassMaterial.lightTopLeft.dx +
        n.dy * GlassMaterial.lightTopLeft.dy;
    final double b = n.dx * GlassMaterial.lightBottomRight.dx +
        n.dy * GlassMaterial.lightBottomRight.dy;
    return math.pow(math.max(a, 0.0), k).toDouble() +
        math.pow(math.max(b, 0.0), k).toDouble();
  }

  /// Walks the outline in segments, each lit from its own normal.
  ///
  /// A linear gradient cannot do this: it follows one axis of the bounding box,
  /// which on a capsule lights the left and right ends, whereas the native glass
  /// lights the top and bottom edges.
  void _paintRim(Canvas canvas, Path path, Offset center, Color color) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = GlassMaterial.rimWidth
      ..strokeCap = StrokeCap.butt
      ..color = color;
    final double peak = color.a;
    for (final ui.PathMetric metric in path.computeMetrics()) {
      final double length = metric.length;
      for (double at = 0; at < length; at += GlassMaterial.rimStep) {
        final ui.Tangent? tangent = metric.getTangentForOffset(at);
        if (tangent == null) continue;
        final Offset t = tangent.vector;
        Offset n = Offset(t.dy, -t.dx);
        if ((tangent.position - center).dx * n.dx +
                (tangent.position - center).dy * n.dy <
            0) {
          n = -n;
        }
        final double alpha = peak * _lit(n);
        if (alpha < 0.004) continue;
        paint.color = color.withValues(alpha: alpha);
        canvas.drawPath(
          metric.extractPath(
            at,
            math.min(at + GlassMaterial.rimStep + 0.5, length),
          ),
          paint,
        );
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0) return;
    final rect = Offset.zero & size;

    // 1) The rim highlight, about half a point wide, lit only on the top-left
    //    and bottom-right arcs.
    //
    // Measured against the native glass for the same spec, scanning column by
    // column: the lit line is only half a point wide — 230 on a body of 205, and
    // the page background immediately above it. The previous three strokes (a
    // 3.6 pt glow along the top, a 5.4 pt shadow along the bottom and a 0.6 pt
    // line) measured as a 7 pt halo inside an 8 pt dark band, far thicker than
    // the native glass. Only the line is kept.
    _paintRim(
      canvas,
      _path(rect.deflate(GlassMaterial.rimInset)),
      rect.center,
      Colors.white.withValues(
        alpha: (isDark
                ? GlassMaterial.rimAlphaDark
                : GlassMaterial.rimAlphaLight) *
            strength,
      ),
    );

    // 2) The dark hairline outside the surface. The native glass is also a
    //    little darker than the page background just outside its edge (-22), and
    //    without it the outline of a capsule blurs away on a white backing.
    canvas.drawPath(
      _path(rect.inflate(GlassMaterial.hairlineInflate)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = GlassMaterial.hairlineWidth
        ..color = Colors.black.withValues(
          alpha: (isDark
                  ? GlassMaterial.hairlineAlphaDark
                  : GlassMaterial.hairlineAlphaLight) *
              strength,
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _GlassRimPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.isDark != isDark ||
        oldDelegate.strength != strength;
  }
}
