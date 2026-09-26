// Capturing what a case looks like, at three levels of detail.
//
// All three go through the same route — let the system render the whole window
// (`captureWindow`, the route the toolbar button uses too):
//
// - whole page: the case list stitched from top to bottom into one image.
// - case: scroll that case into view and cut out the block it occupies.
// - canvases: the same, but cut down to the two canvases side by side.
//
// The cut is not guessed: for the last two, the two canvas rectangles are
// measured off the laid out elements, and that is what gets cut. The two code
// samples are not part of those two crops (the frame does not contain them);
// the whole-page crop shows the page as it is laid out.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../gallery/case_view.dart';
import '../gallery/gallery_stage.dart';
import '../gallery/glass_case.dart';
import 'page_capture.dart';

/// How much of a case a capture covers.
enum CaptureCrop {
  /// The whole page.
  page,

  /// One block per case: its headline, its two canvases, and the two samples.
  item,

  /// One strip per case: the two canvases only.
  canvas,
}

/// One capture: its entry in the manifest, plus the image itself.
///
/// When the capture failed [png] is null and [note] carries the reason — the
/// manifest still comes back, so the caller can see which capture failed.
class CaptureShot {
  CaptureShot(this.note, this.png);

  final Map<String, Object?> note;
  final Uint8List? png;
}

/// Captures things from page [page].
///
/// [items] are indices within the page (empty means every case on the page,
/// which only applies to [CaptureCrop.item] and [CaptureCrop.canvas]); [dark]
/// is the appearance — both lanes take their ink from the theme, so switching
/// it moves both at once.
Future<List<CaptureShot>> captureCases({
  required GalleryStage stage,
  required int page,
  required List<int> items,
  required bool dark,
  required CaptureCrop crop,
  int settleMs = 500,
  List<int>? burst,
  BurstTrigger trigger = BurstTrigger.appearance,
}) async {
  final List<GlassCase> cases = stage.allCases[page];
  stage.showPage(page);
  stage.dark = dark;
  await settleView(millis: settleMs);

  final ScrollPosition position = stage.scroll.position;
  final double was = position.pixels;
  try {
    if (crop == CaptureCrop.page) {
      final CapturedPage captured = await captureWholePage(
        controller: stage.scroll,
        viewportKey: stage.viewportKey,
        background: stage.background,
      );
      return <CaptureShot>[
        CaptureShot(
          <String, Object?>{
            'page': stage.pageLabels[page],
            'crop': 'page',
            'title': 'whole page',
            'cases': cases.length,
            'dark': dark,
            'points': _sides(captured.points),
            'pixels': _sides(captured.points),
          },
          captured.png,
        ),
      ];
    }

    final List<int> picked = items.isEmpty
        ? <int>[for (int i = 0; i < cases.length; i++) i]
        : items.where((int i) => i >= 0 && i < cases.length).toList();
    if (burst != null) {
      if (picked.length != 1) {
        throw const FormatException(
            'a burst takes one case at a time: give a single item index');
      }
      return await captureBurst(
        stage: stage,
        page: page,
        item: cases[picked.single],
        index: picked.single,
        crop: crop,
        dark: dark,
        offsets: burst,
        settleMs: settleMs,
        trigger: trigger,
      );
    }
    final List<CaptureShot> captures = <CaptureShot>[];
    for (final int index in picked) {
      captures.add(
        await _captureOne(
            stage, page, cases[index], index, crop, dark, settleMs),
      );
    }
    return captures;
  } finally {
    if (stage.scroll.hasClients) {
      stage.scroll.jumpTo(
        was.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    }
  }
}

/// Which change a burst measures the transition of.
enum BurstTrigger {
  /// The appearance change (switching to the target step).
  appearance,

  /// Remounting: scroll the case away and back, and measure the moment it
  /// mounts again.
  mount,
}

/// Captures several frames after one change — the transition itself.
///
/// The scene is first put on the **other** appearance step (that change is not
/// measured), scrolled to the case and left to settle; then it switches to
/// [dark] and one frame is captured at each offset in [offsets] from that
/// moment. Each frame's `at` is the real time it was captured (the capture
/// itself takes tens of milliseconds, so it is slightly later than asked for);
/// a curve should be drawn from that number, not from the one requested.
///
/// The use for this: on an appearance change the system's layer cross-fades,
/// which on this machine looks like the native glass changing colour once, and
/// its duration and shape are what the fallback needs comparing against.
Future<List<CaptureShot>> captureBurst({
  required GalleryStage stage,
  required int page,
  required GlassCase item,
  required int index,
  required CaptureCrop crop,
  required bool dark,
  required List<int> offsets,
  int settleMs = 500,
  BurstTrigger trigger = BurstTrigger.appearance,
}) async {
  stage.showPage(page);
  // The mount step wants the target appearance from the start; the appearance
  // step starts on the other one, so that the change measured later is real.
  stage.dark = trigger == BurstTrigger.appearance ? !dark : dark;
  await settleView(millis: settleMs);
  CaptureShot miss(String said) => CaptureShot(
        <String, Object?>{
          'page': stage.pageLabels[page],
          'crop': crop == CaptureCrop.canvas ? 'canvas' : 'item',
          'index': index,
          'dark': dark,
          'error': said,
        },
        null,
      );
  final Element? found = await _reveal(stage, item, settleMs);
  if (found == null) return <CaptureShot>[miss('that case is not laid out')];
  final List<Rect> canvases = _canvasesIn(found);
  final Rect? area = crop == CaptureCrop.canvas
      ? _union(canvases)
      : _caseBlock(found, canvases);
  if (area == null) return <CaptureShot>[miss('nothing to measure there')];

  final List<CaptureShot> out = <CaptureShot>[];
  final Stopwatch watch = Stopwatch()..start();
  if (trigger == BurstTrigger.appearance) {
    stage.dark = dark;
  } else {
    // The mount step: scroll the case out of view (the list is lazy, so it is
    // disposed once out of sight), let it settle, then scroll back — the moment
    // it is back is the moment it mounts again, and the clock starts there.
    final double here = stage.scroll.position.pixels;
    stage.scroll.jumpTo(0);
    await settleView(millis: settleMs);
    if (_caseIn(stage.viewportKey.currentContext as Element, item) != null) {
      return <CaptureShot>[
        miss('that case was not disposed: it is still in view at the top')
      ];
    }
    stage.scroll.jumpTo(here);
    watch.reset();
  }
  for (final int at in offsets) {
    final int left = at - watch.elapsedMilliseconds;
    if (left > 0) {
      await settleView(millis: left);
    } else {
      WidgetsBinding.instance.scheduleFrame();
    }
    final int now = watch.elapsedMilliseconds;
    final WindowImage window = await captureWindow();
    try {
      final Map<String, Object?> note = <String, Object?>{
        'page': stage.pageLabels[page],
        'crop': crop == CaptureCrop.canvas ? 'canvas' : 'item',
        'index': index,
        'title': item.title,
        'dark': dark,
        'asked': at,
        'at': now,
        'points': _sides(area.size),
        'pixels': _sides(
          Size(area.width * window.scale, area.height * window.scale),
        ),
        if (canvases.isNotEmpty) ...<String, Object?>{
          'canvases': <Object?>[
            for (final Rect each in canvases) _box(each.shift(-area.topLeft)),
          ],
          'glasses': <Object?>[
            for (final Rect each in canvases)
              _box(glassIn(each, item).shift(-area.topLeft)),
          ],
        },
      };
      out.add(CaptureShot(note, await cropWindow(window, area)));
    } finally {
      window.image.dispose();
    }
  }
  return out;
}

/// Captures one area of one case.
Future<CaptureShot> _captureOne(
  GalleryStage stage,
  int page,
  GlassCase item,
  int index,
  CaptureCrop crop,
  bool dark,
  int settleMs,
) async {
  final Map<String, Object?> note = <String, Object?>{
    'page': stage.pageLabels[page],
    'crop': crop == CaptureCrop.canvas ? 'canvas' : 'item',
    'index': index,
    'title': item.title,
    'dark': dark,
  };

  final Element? found = await _reveal(stage, item, settleMs);
  if (found == null) {
    note['error'] = 'that case is not laid out';
    return CaptureShot(note, null);
  }
  // When the case was already in view [_reveal] does not move it and therefore
  // does not wait for it; still wait for a settled frame before capturing.
  await settleView(millis: settleMs);
  final List<Rect> canvases = _canvasesIn(found);
  final Rect? area = crop == CaptureCrop.canvas
      ? _union(canvases)
      : _caseBlock(found, canvases);
  if (area == null) {
    note['error'] = 'nothing to measure there';
    return CaptureShot(note, null);
  }

  final WindowImage window = await captureWindow();
  try {
    final Uint8List png = await cropWindow(window, area);
    final Rect inside = window.inImage(area);
    note['points'] = _sides(area.size);
    note['pixels'] = _sides(
      Size(area.width * window.scale, area.height * window.scale),
    );
    note['fits'] = inside.left >= 0 &&
        inside.top >= 0 &&
        inside.right <= window.pixels.width &&
        inside.bottom <= window.pixels.height;
    if (canvases.isNotEmpty) {
      note['canvases'] = <Object?>[
        for (final Rect each in canvases) _box(each.shift(-area.topLeft)),
      ];
      note['glasses'] = <Object?>[
        for (final Rect each in canvases)
          _box(glassIn(each, item).shift(-area.topLeft)),
      ];
    }
    return CaptureShot(note, png);
  } finally {
    window.image.dispose();
  }
}

/// Scrolls the case showing [item] into view and returns the element it was
/// laid out from.
///
/// The list is lazy: a case only exists once it has been scrolled near. When it
/// is already there (the case captured last usually still is) it is centred
/// straight away; otherwise the search walks down one screen at a time from the
/// top — the same screen-by-screen walk, not a jump to an estimated bottom (the
/// estimate keeps moving, so a jump lands in the wrong place).
Future<Element?> _reveal(
    GalleryStage stage, GlassCase item, int settleMs) async {
  final BuildContext? context = stage.viewportKey.currentContext;
  if (context is! Element || !stage.scroll.hasClients) return null;
  // The context is not touched again below (it does not survive an await); only
  // the element tree hanging off it is kept.
  final Element tree = context;
  final ScrollPosition at = stage.scroll.position;
  if (at.viewportDimension < 1) return null;
  final Rect? view = _rectOf(tree);
  if (view == null) return null;

  if (_caseIn(tree, item) != null) {
    return _center(at, tree, item, view, settleMs);
  }

  for (double top = 0;; top += at.viewportDimension) {
    at.jumpTo(math.min(top, at.maxScrollExtent));
    await settleView(millis: settleMs);
    if (_caseIn(tree, item) != null) {
      return _center(at, tree, item, view, settleMs);
    }
    if (at.pixels >= at.maxScrollExtent - 1) return null;
  }
}

/// Centres the case in the viewport, so the whole block fits inside the window
/// with room above and below when it is cut out.
Future<Element?> _center(
  ScrollPosition at,
  Element tree,
  GlassCase item,
  Rect view,
  int settleMs,
) async {
  final Rect? rect = _rectOf(_caseIn(tree, item)!);
  if (rect != null) {
    final double delta = rect.center.dy - view.center.dy;
    if (delta.abs() > 1) {
      at.jumpTo(
        (at.pixels + delta)
            .clamp(at.minScrollExtent, at.maxScrollExtent)
            .toDouble(),
      );
      await settleView(millis: settleMs);
    }
  }
  return _caseIn(tree, item);
}

/// The case under [tree] showing [item] (null while it is not laid out).
///
/// Every case in the list is given the same [GlassCase] instance (the tables in
/// `capsule_cases.dart` and `title_cases.dart` are built once and reused), so
/// identity is what is matched.
Element? _caseIn(Element tree, GlassCase item) {
  Element? found;
  void walk(Element each) {
    if (found != null) return;
    final Widget widget = each.widget;
    if (widget is CaseView && identical(widget.item, item)) {
      found = each;
      return;
    }
    each.visitChildren(walk);
  }

  tree.visitChildren(walk);
  return found;
}

/// The rectangles the two canvases under [item] occupy (global coordinates).
List<Rect> _canvasesIn(Element item) {
  final List<Rect> rects = <Rect>[];
  void walk(Element each) {
    if (each.widget is CanvasPane) {
      final Rect? rect = _rectOf(each);
      if (rect != null) rects.add(rect);
    }
    each.visitChildren(walk);
  }

  item.visitChildren(walk);
  return rects;
}

/// The block one case occupies: the headline at the top down to the bottom of
/// the two code samples, horizontally the stretch containing both lanes.
///
/// The horizontal extent is taken from the two canvases because a case's row is
/// wider than the two lanes (there is empty space on the right), and capturing
/// the whole row would add a strip of page background.
Rect? _caseBlock(Element item, List<Rect> canvases) {
  final Rect? whole = _rectOf(item);
  if (whole == null) return null;
  final Rect? lanes = _union(canvases);
  if (lanes == null) return whole;
  return Rect.fromLTRB(lanes.left, whole.top, lanes.right, whole.bottom);
}

/// The rectangle an element is laid out at (global coordinates).
Rect? _rectOf(Element element) {
  final RenderObject? object = element.findRenderObject();
  if (object is! RenderBox || !object.hasSize) return null;
  return object.localToGlobal(Offset.zero) & object.size;
}

/// The rectangle containing all of [rects].
Rect? _union(List<Rect> rects) => rects.isEmpty
    ? null
    : rects.reduce((Rect a, Rect b) => a.expandToInclude(b));

/// `[width, height]`.
List<Object?> _sides(Size size) => <Object?>[
      size.width.round(),
      size.height.round(),
    ];

/// The rectangle the glass occupies inside one canvas (a logical rectangle
/// within the canvas).
///
/// Both columns use the same arithmetic: the glass leaves the edges at 16 and
/// its own end (8 at the top for a title bar, 14 above and 8 below for a
/// capsule), which are the same numbers the package pads with
/// (`lib/src/theme/glass_metrics.dart`). The native column's platform view is
/// exactly this rectangle and the fallback's painted glass lands in it too, so
/// comparing the two columns against this rectangle cannot drift onto the text
/// or the icons.
Rect glassIn(Rect pane, GlassCase item) {
  const double side = 16;
  const double top = 8;
  const double capsuleBottom = 8;
  if (!item.atTop) {
    return Rect.fromLTRB(
      pane.left + side,
      pane.bottom - capsuleBottom - item.barHeight,
      pane.right - side,
      pane.bottom - capsuleBottom,
    );
  }
  return Rect.fromLTRB(
    pane.left + side,
    pane.top + top,
    pane.right - side,
    pane.top + top + item.barHeight,
  );
}

/// `[left, top, width, height]`.
List<Object?> _box(Rect rect) => <Object?>[
      rect.left.round(),
      rect.top.round(),
      rect.width.round(),
      rect.height.round(),
    ];
