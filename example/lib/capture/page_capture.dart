// Capturing this window, and stitching the case list into one whole page.
//
// The case list is far taller than the window, and the window is at most one
// screen (the system does not give a window taller than the display); the glass
// the native renderer draws does not go into Flutter's own canvas either. So
// the only way is to scroll one screen at a time — each screen rendered by the
// system — and stitch them together. The result is 1× pixels (what comes back
// is the window's pixels, 2× on this machine) and is handed over as one whole
// page, so the receiver does not have to scroll.
//
// Two callers use this: the button at the top right (stitches, then puts it on
// the clipboard) and the capture server (stitches, then serves it from
// `/file/<id>`). The stitching itself lives here, once.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The channel agreed with the macOS side
/// (`macos/Runner/MainFlutterWindow.swift`).
///
/// `captureWindow` returns a PNG of this window right now plus how it lines up
/// with Flutter's layer; `pasteImage` puts a stitched image on the clipboard.
/// Other platforms have no such channel, and say so when pressed.
const MethodChannel captureChannel = MethodChannel(
  'swiftui_kit_example/screenshot',
);

/// A capture that failed: why, and what to show the user.
class PageCaptureError implements Exception {
  const PageCaptureError(this.said);

  /// The line the toolbar button shows in place.
  final String said;

  @override
  String toString() => said;
}

/// A stitched whole page: the PNG, and its size in logical points.
class CapturedPage {
  const CapturedPage({required this.png, required this.points});

  final Uint8List png;

  /// How large this page is in logical points (the width of the case list, the
  /// height of the whole page).
  final Size points;
}

/// Captures the list behind [viewportKey] from top to bottom as one image.
///
/// [controller] must be that list's; [background] fills whatever the stitching
/// does not cover; [progress] is called once per screen captured.
///
/// It moves down one screen at a time and captures each one, and only treats a
/// screen that will not move as the bottom. The total height is not measured up
/// front: a lazily laid out list only builds what it has scrolled to, and its
/// `maxScrollExtent` is estimated from the cases built so far (cases differ in
/// height, and the first frame after a width change is laid out at a narrower
/// width), so the estimate keeps moving. Jumping straight to the estimated
/// bottom either cuts a section off or leaves a blank strip. Once the bottom is
/// reached the captured positions are stitched; afterwards the list scrolls
/// back to where it was.
Future<CapturedPage> captureWholePage({
  required ScrollController controller,
  required GlobalKey viewportKey,
  required Color background,
  void Function(int done)? progress,
}) async {
  final RenderObject? object = viewportKey.currentContext?.findRenderObject();
  if (object is! RenderBox || !object.hasSize) {
    throw const PageCaptureError('the case list was not found');
  }
  final Offset at = object.localToGlobal(Offset.zero);
  final double wide = object.size.width;
  final double tall = object.size.height;
  if (wide < 1 || tall < 1) {
    throw const PageCaptureError('the case list is not laid out yet');
  }

  final ScrollPosition position = controller.position;
  final double was = position.pixels;
  final List<(double, WindowImage)> captured = <(double, WindowImage)>[];
  try {
    double here = position.pixels;
    for (int i = 0; i < 64; i++) {
      // Clamp into the list's range before jumping: `jumpTo` does not clamp
      // itself, and overshooting it is accepted (that screen is blank).
      controller.jumpTo(math.min(here, position.maxScrollExtent));
      await settleView();
      final double top = position.pixels;
      captured.add((top, await captureWindow()));
      progress?.call(captured.length);
      final double next = top + tall;
      // This screen does not reach the estimated bottom yet: carry on down.
      if (next < position.maxScrollExtent - 1) {
        here = next;
        continue;
      }
      // This screen already reaches the estimated bottom: squeeze down to the
      // lowest position in range and see whether it still moves. If it does,
      // the bottom is still growing (the estimate follows the cases built so
      // far) and another screen is needed; if it does not, this is the bottom.
      controller.jumpTo(math.min(next, position.maxScrollExtent));
      await settleView();
      if (position.pixels <= top + 1) break;
      here = position.pixels;
    }

    final double total = captured.last.$1 + tall;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, wide, total),
      Paint()..color = background,
    );
    for (final (double top, WindowImage frame) in captured) {
      canvas.drawImageRect(
        frame.image,
        Rect.fromLTWH(
          frame.inset.dx + at.dx * frame.scale,
          frame.inset.dy + at.dy * frame.scale,
          wide * frame.scale,
          tall * frame.scale,
        ),
        Rect.fromLTWH(0, top, wide, tall),
        Paint()..filterQuality = FilterQuality.medium,
      );
    }

    final ui.Image page = await recorder.endRecording().toImage(
          wide.round(),
          total.round(),
        );
    final ByteData? png = await page.toByteData(format: ui.ImageByteFormat.png);
    page.dispose();
    if (png == null) {
      throw const PageCaptureError('the stitched page could not be encoded');
    }
    return CapturedPage(
        png: png.buffer.asUint8List(), points: Size(wide, total));
  } finally {
    for (final (double _, WindowImage frame) in captured) {
      frame.image.dispose();
    }
    controller.jumpTo(was);
  }
}

/// Captures the list behind [viewportKey] from top to bottom, puts it on the
/// clipboard and returns one line about the result.
///
/// [controller] must be that list's; [background] fills whatever the stitching
/// does not cover; [progress] is called once per screen captured, which is what
/// the button uses to report progress.
Future<String> copyWholePageToClipboard({
  required ScrollController controller,
  required GlobalKey viewportKey,
  required Color background,
  void Function(int done)? progress,
}) async {
  try {
    final CapturedPage page = await captureWholePage(
      controller: controller,
      viewportKey: viewportKey,
      background: background,
      progress: progress,
    );
    await captureChannel.invokeMethod<void>('pasteImage', page.png);
    return 'Copied page ${page.points.width.round()}×'
        '${page.points.height.round()}';
  } on MissingPluginException {
    return 'not available on this platform';
  } on PlatformException catch (error) {
    return 'capture failed: ${error.code}';
  } on PageCaptureError catch (error) {
    return error.said;
  }
}

/// One captured window: the image, how many pixels a logical point takes in it,
/// and where the content view's top-left corner sits inside it.
class WindowImage {
  const WindowImage({
    required this.image,
    required this.scale,
    required this.inset,
  });

  final ui.Image image;

  /// How many pixels one logical point takes in the image.
  final double scale;

  /// The content view's top-left corner inside the image (the image starts at
  /// the window's top-left corner, while Flutter's (0,0) is the content view).
  final Offset inset;

  /// How many pixels this image has.
  Size get pixels => Size(image.width.toDouble(), image.height.toDouble());

  /// Where an area measured in logical points (global coordinates) lands in
  /// this image, in pixels.
  Rect inImage(Rect logical) => Rect.fromLTWH(
        inset.dx + logical.left * scale,
        inset.dy + logical.top * scale,
        logical.width * scale,
        logical.height * scale,
      );
}

/// Captures this window as it is right now.
Future<WindowImage> captureWindow() async {
  final Map<Object?, Object?>? reply =
      await captureChannel.invokeMapMethod<Object?, Object?>('captureWindow');
  final Object? bytes = reply?['bytes'];
  if (reply == null || bytes is! Uint8List) {
    throw PlatformException(
        code: 'no-window', message: 'the system returned no window image');
  }
  final ui.Codec codec = await ui.instantiateImageCodec(bytes);
  final ui.FrameInfo frame = await codec.getNextFrame();
  return WindowImage(
    image: frame.image,
    scale: (reply['scale']! as num).toDouble(),
    inset: Offset(
      (reply['offsetX']! as num).toDouble(),
      (reply['offsetY']! as num).toDouble(),
    ),
  );
}

/// Cuts [logical] (a logical rectangle in global coordinates) out of a captured
/// window and encodes it as a PNG.
///
/// The result keeps the original pixels, unscaled; anything outside the window
/// does not count, so the cut is clamped to the window's edges.
Future<Uint8List> cropWindow(WindowImage window, Rect logical) async {
  final Rect area = window.inImage(logical).intersect(
        Rect.fromLTWH(0, 0, window.pixels.width, window.pixels.height),
      );
  final int wide = area.width.round();
  final int tall = area.height.round();
  if (wide < 1 || tall < 1) {
    throw const PageCaptureError('that area is not inside the window');
  }
  final Rect cut = Rect.fromLTWH(
    area.left.floorToDouble(),
    area.top.floorToDouble(),
    wide.toDouble(),
    tall.toDouble(),
  );
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawImageRect(
    window.image,
    cut,
    Rect.fromLTWH(0, 0, wide.toDouble(), tall.toDouble()),
    Paint()..filterQuality = FilterQuality.high,
  );
  final ui.Image image = await recorder.endRecording().toImage(wide, tall);
  final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (png == null) {
    throw const PageCaptureError('the crop could not be encoded');
  }
  return png.buffer.asUint8List();
}

/// Waits for this screen to settle.
///
/// It pushes a frame first (scroll position, layout) and then gives the native
/// glass [millis] milliseconds. Half a second is measured, not guessed: the
/// platform view lags behind the Dart side — after a page change, an appearance
/// change or a scroll it draws one version and only settles into the final one
/// a moment later (on this machine it looks like the native side changing
/// colour once, because that layer cross-fades).
///
/// Frames have to keep being pushed for that half second; a plain delay is not
/// enough, since without a new frame the platform view never moves on.
Future<void> settleView({int millis = 500}) async {
  final int steps = (millis / 20).ceil().clamp(0, 500);
  for (int i = 0; i < steps; i++) {
    WidgetsBinding.instance.scheduleFrame();
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  if (steps == 0) WidgetsBinding.instance.scheduleFrame();
}
