// The wire contract between Dart and the native renderer.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The names and message shapes shared with the native renderer.
///
/// Each entry mirrors a member of `GlassContract` on the Swift side
/// (`shared/swiftui_kit/GlassSupport.swift`). The spec keys are not listed here:
/// they describe a payload whose shape both sides read independently, and they
/// are documented in the README.
abstract final class GlassContract {
  /// The platform view type of the capsule bar.
  static const String capsuleBarViewType = 'swiftui_kit/capsule_bar';

  /// The platform view type of the title bar.
  static const String titleBarViewType = 'swiftui_kit/title_bar';

  /// The prefix shared by both platform view types.
  static const String viewTypePrefix = 'swiftui_kit/';

  /// The method channel of one glass surface.
  ///
  /// Each surface has its own channel so that an event identifies the surface it
  /// came from without the payload having to carry an id.
  static String viewChannelName(int viewId) => 'swiftui_kit/view/$viewId';

  /// Dart to native: push a whole spec.
  static const String updateMethod = 'update';

  /// Native to Dart: report one event.
  static const String eventMethod = 'event';

  /// Event envelope: which event.
  static const String keyType = 'type';

  /// Event envelope: which item was activated.
  static const String keyIndex = 'index';

  /// Event envelope: the text of the search field.
  static const String keyText = 'text';
}

/// The events the native renderer reports.
///
/// The wire names match the `payload` of `GlassOutgoing` on the Swift side.
enum GlassEventType {
  /// An item was activated. [GlassEvent.index] indexes the list the caller
  /// supplied.
  itemTap,

  /// The trailing capsule was activated.
  trailingTap,

  /// Search was entered from the capsule bar's magnifier button.
  searchEnter,

  /// The search text changed.
  searchChanged,

  /// The search text was submitted.
  searchSubmitted,

  /// Cancel was activated.
  searchCancel;

  /// The name used on the channel.
  String get wire => name;

  /// Parses a wire name. Returns null for anything unknown, which callers treat
  /// as "no event" rather than as an error.
  static GlassEventType? fromWire(Object? wire) {
    for (final type in GlassEventType.values) {
      if (type.wire == wire) return type;
    }
    return null;
  }
}

/// One event reported by the native renderer.
@immutable
class GlassEvent {
  const GlassEvent(this.type, {this.index, this.text});

  /// Decodes a method call received on a glass channel.
  ///
  /// Returns null when the call is not an event, or carries an event type this
  /// version does not know: an unknown event is ignored, not treated as an
  /// error.
  static GlassEvent? decode(MethodCall call) {
    if (call.method != GlassContract.eventMethod) return null;
    final args = call.arguments;
    if (args is! Map) return null;
    final type = GlassEventType.fromWire(args[GlassContract.keyType]);
    if (type == null) return null;
    final index = args[GlassContract.keyIndex];
    final text = args[GlassContract.keyText];
    return GlassEvent(
      type,
      index: index is int ? index : null,
      text: text is String ? text : null,
    );
  }

  /// Which event.
  final GlassEventType type;

  /// Which item was activated. Only set for [GlassEventType.itemTap].
  final int? index;

  /// The search text. Only set for [GlassEventType.searchChanged] and
  /// [GlassEventType.searchSubmitted].
  final String? text;

  @override
  String toString() => 'GlassEvent($type, index: $index, text: $text)';
}
