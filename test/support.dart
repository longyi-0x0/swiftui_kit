// Test scaffolding that intercepts the two channels between Dart and the native
// renderer: SystemChannels.platform_views (create, dispose) and each surface's
// own `swiftui_kit/view/<id>` channel (spec pushes, events).

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftui_kit/src/native/glass_contract.dart';

/// One intercepted pair of channels.
class FakeHost {
  FakeHost() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      SystemChannels.platform_views,
      _onPlatformView,
    );
  }

  /// The create calls received. There is only ever one.
  final List<MethodCall> created = <MethodCall>[];

  /// Every subsequent `update`. The spec is pushed only when it changes.
  final List<Map<Object?, Object?>> pushes = <Map<Object?, Object?>>[];

  /// Events reported by the native side.
  final List<Map<Object?, Object?>> events = <Map<Object?, Object?>>[];

  /// The id of the created platform view.
  int? viewId;

  Future<Object?> _onPlatformView(MethodCall call) async {
    if (call.method != 'create') return null;
    created.add(call);
    final Map<Object?, Object?> args = call.arguments! as Map<Object?, Object?>;
    final int id = args['id']! as int;
    viewId = id;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      MethodChannel(GlassContract.viewChannelName(id)),
      _onViewChannel,
    );
    return null;
  }

  Future<Object?> _onViewChannel(MethodCall call) async {
    if (call.method == 'update') {
      pushes.add(call.arguments! as Map<Object?, Object?>);
    }
    return null;
  }

  /// The view type, such as `swiftui_kit/capsule_bar`.
  String get viewType => creationParams['viewType']! as String;

  /// The creation parameters, as one table.
  Map<Object?, Object?> get creationParams =>
      created.single.arguments! as Map<Object?, Object?>;

  /// The spec from the creation parameters.
  ///
  /// Creation parameters travel through the standard codec — the same one Swift
  /// decodes with — so they arrive here as encoded bytes.
  Map<Object?, Object?> get spec {
    final Uint8List bytes = creationParams['params']! as Uint8List;
    return const StandardMessageCodec().decodeMessage(
      ByteData.sublistView(bytes),
    )! as Map<Object?, Object?>;
  }

  /// The spec pushed most recently.
  Map<Object?, Object?> get lastPush => pushes.last;

  /// Reports one event as if it came from the native side.
  Future<void> emit(String type, {int? index, String? text}) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      GlassContract.viewChannelName(viewId!),
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('event', <String, Object?>{
          'type': type,
          if (index != null) 'index': index,
          if (text != null) 'text': text,
        }),
      ),
      (ByteData? _) {},
    );
  }

  void dispose() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, null);
    final int? id = viewId;
    if (id != null) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        MethodChannel(GlassContract.viewChannelName(id)),
        null,
      );
    }
  }
}

/// Runs [body] with this platform pretending to be macOS, which has the native
/// renderer.
///
/// The override has to be cleared as soon as [body] finishes: the test framework
/// checks whether the global was touched the moment the test body returns, so
/// clearing it in `tearDown` is too late.
Future<void> asMacOs(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

/// The intercepted channels, created freshly before each test. See
/// [useFakeHost].
late FakeHost host;

/// Intercepts the channels before each test and releases them afterwards.
void useFakeHost() {
  setUp(() => host = FakeHost());
  tearDown(() => host.dispose());
}
