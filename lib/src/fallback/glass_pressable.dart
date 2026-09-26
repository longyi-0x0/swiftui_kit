// Press feedback shared by the fallback renderer's buttons.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/glass_motion.dart';

/// A tappable area around [child].
///
/// Used by both the capsule items and the title bar items: two different press
/// behaviours on one page would read as two different controls. The child
/// shrinks slightly while pressed and a haptic fires on release.
class GlassPressable extends StatefulWidget {
  const GlassPressable({
    super.key,
    required this.child,
    required this.onPressed,
    this.help,
  });

  /// The content of the button.
  final Widget child;

  /// Called on release. The haptic is fired here too.
  final VoidCallback onPressed;

  /// A tooltip shown on hover, on macOS.
  final String? help;

  @override
  State<GlassPressable> createState() => _GlassPressableState();
}

class _GlassPressableState extends State<GlassPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    Widget child = AnimatedScale(
      scale: _pressed ? GlassMotion.pressScale : 1.0,
      duration: GlassMotion.press,
      curve: GlassMotion.shrink,
      child: widget.child,
    );

    final help = widget.help;
    if (help != null) {
      child = Tooltip(message: help, child: child);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onPressed();
      },
      child: child,
    );
  }
}
