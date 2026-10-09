// Fades a surface in when it is mounted.

import 'package:flutter/material.dart';

import '../theme/glass_motion.dart';

/// Fades [child] in when it is mounted.
///
/// The native renderer is a platform view whose first frame arrives late: for
/// about 100 ms the area still shows the page background instead of the glass.
/// The fallback paints in the same frame as the rest of the content, so without
/// this fade the two are visibly out of step when placed side by side.
///
/// Only the fallback is wrapped: the native view is already late, and adding
/// this on top would double the delay.
///
/// 淡入结束后不再包 [FadeTransition]：它会占满一条矩形合成层，叠在二楼圆角卡片
/// 顶上时，圆角外的楔形仍落在这一层范围里，再加子树里的 BackdropFilter，会把后面
/// 的二楼挡住。
class EntranceFade extends StatefulWidget {
  const EntranceFade({
    super.key,
    required this.child,
    this.duration = GlassMotion.entranceFade,
  });

  /// The surface to fade in.
  final Widget child;

  /// How long the fade takes.
  final Duration duration;

  @override
  State<EntranceFade> createState() => _EntranceFadeState();
}

class _EntranceFadeState extends State<EntranceFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final CurvedAnimation _opacity = CurvedAnimation(
    parent: _controller,
    curve: GlassMotion.fadeOut,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _opacity.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        if (_controller.value >= 1.0 - 1e-6) return child!;
        return FadeTransition(opacity: _opacity, child: child!);
      },
    );
  }
}
