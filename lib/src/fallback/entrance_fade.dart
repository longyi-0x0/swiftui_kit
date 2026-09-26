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

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity:
            CurvedAnimation(parent: _controller, curve: GlassMotion.fadeOut),
        child: widget.child,
      );
}
