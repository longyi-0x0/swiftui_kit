// The host widget for one glass surface drawn by the native renderer.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'glass_contract.dart';

/// A glass surface drawn by SwiftUI inside a platform view.
///
/// On iOS this is a `UiKitView`, on macOS an `AppKitView`. The area given by the
/// caller is the frame of the native content, which fills it; padding is applied
/// by the caller.
///
/// The spec is passed as the creation parameter and pushed again through
/// [GlassContract.updateMethod] whenever it changes. The view itself is never
/// rebuilt, because rebuilding would lose the search state, the keyboard focus
/// and any indicator animation in flight. Events come back on a per-view
/// channel, which is what lets a payload identifying "which item" stay
/// unambiguous.
class NativeGlassView extends StatefulWidget {
  const NativeGlassView({
    super.key,
    required this.viewType,
    required this.spec,
    this.onEvent,
  });

  /// One of [GlassContract.capsuleBarViewType] or
  /// [GlassContract.titleBarViewType].
  final String viewType;

  /// What to draw. See the README for the key names agreed with the native side.
  final Map<String, Object?> spec;

  /// Events reported by the native side.
  final ValueChanged<GlassEvent>? onEvent;

  @override
  State<NativeGlassView> createState() => _NativeGlassViewState();
}

class _NativeGlassViewState extends State<NativeGlassView> {
  MethodChannel? _channel;

  /// The spec pushed last, encoded. An identical spec is not pushed again.
  String? _pushed;

  void _attach(int viewId) {
    final channel = MethodChannel(GlassContract.viewChannelName(viewId));
    channel.setMethodCallHandler(_onCall);
    _channel = channel;
    _pushed = null;
    _push();
  }

  Future<Object?> _onCall(MethodCall call) async {
    final event = GlassEvent.decode(call);
    if (event != null) widget.onEvent?.call(event);
    return null;
  }

  void _push() {
    final channel = _channel;
    if (channel == null) return;
    final json = jsonEncode(widget.spec);
    if (json == _pushed) return;
    _pushed = json;
    channel.invokeMethod<void>(GlassContract.updateMethod, widget.spec);
  }

  @override
  void didUpdateWidget(covariant NativeGlassView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.viewType != oldWidget.viewType) {
      // A different view type means a different platform view, and the old
      // channel went away with the old one.
      _channel?.setMethodCallHandler(null);
      _channel = null;
      _pushed = null;
      return;
    }
    _push();
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    _channel = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => UiKitView(
          viewType: widget.viewType,
          creationParams: widget.spec,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _attach,
        ),
      _ => AppKitView(
          viewType: widget.viewType,
          creationParams: widget.spec,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _attach,
        ),
    };
  }
}
