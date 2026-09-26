// The search row drawn inside a glass surface.

import 'package:flutter/material.dart';

import '../theme/glass_ink.dart';
import '../theme/glass_metrics.dart';
import '../theme/glass_typography.dart';

/// The cancel action drawn inside a glass surface.
///
/// Shared by the capsule bar and the title bar. The only difference between the
/// two is horizontal padding: inside the round capsule it is tightened.
class GlassSearchCancel extends StatelessWidget {
  const GlassSearchCancel({
    super.key,
    required this.ink,
    required this.onPressed,
    required this.label,
    this.height,
    this.opacity = 1.0,
    this.tight = false,
  });

  /// The ink, shared with the rest of the surface.
  final GlassInk ink;

  /// Called when the action is activated.
  final VoidCallback? onPressed;

  /// The label.
  final String label;

  /// The height of the tappable area. Defaults to the height of the text.
  final double? height;

  /// Opacity, reduced while search is being entered or left.
  final double opacity;

  /// Whether to tighten the horizontal padding, for use inside the capsule.
  final bool tight;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: ink.action,
            minimumSize: height == null ? null : Size(0, height!),
            padding: EdgeInsets.symmetric(
              horizontal: tight
                  ? GlassMetrics.searchCancelPadTight
                  : GlassMetrics.searchCancelPad,
            ),
            textStyle: const TextStyle(fontSize: GlassTypography.title),
          ),
          child: Text(label),
        ),
      );
}

/// The search row drawn inside a glass surface: icon, field, and optionally the
/// cancel action.
class GlassSearchField extends StatelessWidget {
  const GlassSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.ink,
    required this.prompt,
    required this.cancelLabel,
    this.onChanged,
    this.onSubmitted,
    this.onCancel,
    this.cancelOpacity = 1.0,
    this.leadingPad = GlassMetrics.searchLeadingPad,
  });

  /// The text being edited.
  final TextEditingController controller;

  /// The focus node of the field.
  final FocusNode focusNode;

  /// The ink, shared with the rest of the surface.
  final GlassInk ink;

  /// The placeholder.
  final String prompt;

  /// The label of the cancel action.
  final String cancelLabel;

  /// The search text changed.
  final ValueChanged<String>? onChanged;

  /// The search text was submitted.
  final ValueChanged<String>? onSubmitted;

  /// When null no cancel action is drawn here, because the surface draws one of
  /// its own, as the title bar does at the trailing end.
  final VoidCallback? onCancel;

  /// Opacity of the cancel action, reduced while search is being entered or
  /// left.
  final double cancelOpacity;

  /// Padding at the leading end. Wider inside the capsule.
  final double leadingPad;

  @override
  Widget build(BuildContext context) {
    final onCancel = this.onCancel;
    return Row(
      children: <Widget>[
        SizedBox(width: leadingPad),
        Icon(Icons.search, size: GlassMetrics.searchIconSize, color: ink.hint),
        const SizedBox(width: GlassMetrics.searchIconGap),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration.collapsed(
              hintText: prompt,
              hintStyle: TextStyle(
                color: ink.hint,
                fontSize: GlassTypography.title,
              ),
            ),
            style: TextStyle(
              fontSize: GlassTypography.title,
              color: ink.foreground,
            ),
            cursorColor: ink.primary,
            textInputAction: TextInputAction.search,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
          ),
        ),
        if (onCancel != null)
          GlassSearchCancel(
            ink: ink,
            onPressed: onCancel,
            label: cancelLabel,
            opacity: cancelOpacity,
            tight: true,
          ),
      ],
    );
  }
}
