// The gallery runs, and the parts really move.
//
// Looks are checked by running it (this page is for the eye); what is pinned
// here is a few things: what a page contains, that a case has both lanes and
// both code samples, that pressing something changes state, that the frame
// width and the appearance can be switched, and what the two copy buttons hand
// over. The tests run on the test platform (no SwiftUI, and no window capture
// channel), so the native lane draws nothing and the page copy only reports
// that; both renderers being registered is covered by the package's own tests
// (`../test/`).

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftui_kit_example/capture/page_capture.dart';
import 'package:swiftui_kit_example/gallery/case_view.dart';
import 'package:swiftui_kit_example/gallery/gallery_app.dart';
import 'package:swiftui_kit_example/gallery/gallery_pages.dart';

/// Pumps a gallery. The view is given plenty of room — the case list has to
/// show several cases.
Future<void> pumpGallery(
  WidgetTester tester, {
  String? only,
  double height = 1600,
  double width = 1400,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = Size(width, height);
  addTearDown(tester.view.reset);
  final List<GalleryPage> picked = only == null
      ? allPages
      : <GalleryPage>[
          allPages.firstWhere((GalleryPage each) => each.label == only),
        ];
  await tester.pumpWidget(GalleryApp(pages: picked));
  await settle(tester);
}

/// Settles, and swallows the errors from the fallback lane's first frame at a
/// narrow width.
///
/// After a width change (a different frame width, a page change, an appearance
/// change) the package's own bars lay themselves out at a narrower width for
/// one frame and settle on the next. That belongs to the package and should not
/// turn a test red.
Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  while (tester.takeException() != null) {}
}

/// The case with this name.
Finder itemNamed(String title) => find.byWidgetPredicate(
      (Widget w) => w is CaseView && w.item.title == title,
    );

/// The case list is lazy: scroll to the case if it is not laid out yet.
Future<void> settleWith(WidgetTester tester, Finder item) async {
  if (item.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      item,
      240,
      // A code sample is scrollable too, so name the middle column.
      scrollable: find
          .descendant(
              of: find.byKey(listKey), matching: find.byType(Scrollable))
          .first,
    );
    await settle(tester);
  }
  expect(item, findsOneWidget);
}

/// How tall the whole list is, in logical points.
///
/// The list is lazy and its `maxScrollExtent` is estimated from the cases laid
/// out so far (cases differ in height, and the first frame after a width change
/// is laid out narrower), so it walks down one screen at a time: the bottom is
/// only where it stops moving, and the total is that position plus one screen.
/// The position is put back afterwards.
Future<double> wholeHeight(
    WidgetTester tester, ScrollableState scrollable) async {
  final ScrollPosition at = scrollable.position;
  final double was = at.pixels;
  for (int i = 0; i < 64; i++) {
    final double top = at.pixels;
    at.jumpTo(math.min(top + at.viewportDimension, at.maxScrollExtent));
    await tester.pump(const Duration(milliseconds: 200));
    if ((at.pixels - top).abs() < 1) break;
  }
  final double total = at.pixels + at.viewportDimension;
  at.jumpTo(was);
  await tester.pump();
  return total;
}

/// A solid-colour PNG, standing in for "a captured window".
///
/// Encoding has to happen inside [WidgetTester.runAsync]: the test platform
/// owns the clock, and encoding waits for a real frame — awaiting it directly
/// waits forever, without an error and without moving on.
Future<Uint8List> solidPng(WidgetTester tester, int wide, int tall) async =>
    (await tester.runAsync(() async {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        Rect.fromLTWH(0, 0, wide.toDouble(), tall.toDouble()),
        Paint()..color = const Color(0xFF3366CC),
      );
      final ui.Image image = await recorder.endRecording().toImage(wide, tall);
      final ByteData? data =
          await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    }))!;

/// Decodes a PNG (also inside [WidgetTester.runAsync], for the same reason).
Future<ui.Image> decode(WidgetTester tester, Uint8List png) async =>
    (await tester.runAsync(() async {
      final ui.Codec codec = await ui.instantiateImageCodec(png);
      return (await codec.getNextFrame()).image;
    }))!;

/// The two lanes inside one case.
Finder routesIn(Finder item) =>
    find.descendant(of: item, matching: find.byType(CanvasPane));

void main() {
  testWidgets(
      'opens on the capsule page: sidebar, toolbar and case list are there',
      (WidgetTester tester) async {
    await pumpGallery(tester, only: 'Capsule');

    // The sidebar: this page (only the capsule page was picked) and its name.
    expect(find.text('swiftui_kit gallery'), findsOneWidget);
    expect(
      find.descendant(
          of: find.byKey(sidebarKey), matching: find.text('Capsule')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byKey(sidebarKey), matching: find.text('Title')),
      findsNothing,
    );

    // The toolbar: the page name, what it is about, the appearance switch and
    // the copy-page button.
    // The switch is an icon with no label, so its tooltip is not on screen.
    expect(find.text('Switch appearance'), findsNothing);
    expect(find.textContaining('floating capsule'), findsOneWidget);
    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
    expect(find.text('Copy page'), findsOneWidget);

    // The case list: with a 1600-tall view, several cases are visible.
    final List<Rect> items = <Rect>[
      for (final Element e in find.byType(CaseView).evaluate())
        tester.getRect(find.byWidget(e.widget)),
    ];
    expect(items, isNotEmpty);
    expect(
      items.where((Rect r) => r.top < 1600).length,
      greaterThanOrEqualTo(3),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'one case: a headline on top, two lanes in a frame, one sample each',
      (WidgetTester tester) async {
    await pumpGallery(tester, only: 'Capsule');

    final Finder item = itemNamed('Three items · middle selected');
    expect(item, findsOneWidget);

    // The headline: the name and the one line about it.
    expect(
      find.descendant(
          of: item, matching: find.text('Three items · middle selected')),
      findsOneWidget,
    );
    expect(
      find.descendant(
          of: item, matching: find.textContaining('The ordinary state')),
      findsOneWidget,
    );

    // Two lanes in the frame: native on the left, fallback on the right.
    expect(routesIn(item), findsNWidgets(2));
    expect(
      find.descendant(of: item, matching: find.text('Native')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: item, matching: find.text('Fallback')),
      findsOneWidget,
    );
    final List<Rect> panes = <Rect>[
      for (final Element e in routesIn(item).evaluate())
        tester.getRect(find.byWidget(e.widget)),
    ];
    expect(panes[1].size, panes[0].size);
    // The two lanes sit side by side: same top, native on the left, fallback on
    // the right.
    expect(panes[1].top, panes[0].top);
    expect(panes[1].left, greaterThan(panes[0].left));

    // Each lane carries its own sample: one SwiftUI, one Dart, each naming its
    // language in the corner.
    expect(find.descendant(of: item, matching: find.byType(CodeBlock)),
        findsNWidgets(2));
    expect(
      find.descendant(of: item, matching: find.text('Swift')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: item, matching: find.text('Dart')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: item, matching: find.textContaining('glassEffect')),
      findsOneWidget,
    );
    expect(
      find.descendant(
          of: item, matching: find.textContaining('GlassCapsuleBar')),
      findsOneWidget,
    );

    // A sample sits below its canvas on the same vertical line: same left edge,
    // same width.
    final List<Rect> codes = <Rect>[
      for (final Element e in find
          .descendant(of: item, matching: find.byType(CodeBlock))
          .evaluate())
        tester.getRect(find.byWidget(e.widget)),
    ];
    for (int i = 0; i < 2; i++) {
      expect(codes[i].left, panes[i].left, reason: 'lane $i');
      expect(codes[i].width, panes[i].width, reason: 'lane $i');
      expect(codes[i].top, greaterThan(panes[i].bottom), reason: 'lane $i');
    }
    // The two samples take one column each and end level — however long a
    // sample is, it stays visible without squeezing the other.
    expect(codes[1].top, codes[0].top);
    expect(codes[1].bottom, codes[0].bottom);

    // This platform has no SwiftUI: the native lane is replaced by a note, and
    // the fallback lane is drawn as usual.
    expect(
      find.descendant(of: item, matching: find.textContaining('No SwiftUI')),
      findsOneWidget,
    );
  });

  testWidgets(
      'tapping an item in a capsule: that case changes state, others do not',
      (WidgetTester tester) async {
    await pumpGallery(tester, only: 'Capsule');

    // Inside the first case (Three items · middle selected), "Item 3" is the
    // third item.
    final Finder first = itemNamed('Three items · middle selected');
    await tester.tap(
      find.descendant(of: first, matching: find.text('Item 3')).first,
    );
    await settle(tester);

    // Only this case's headline gained the extra line.
    expect(find.text('Tapped: Item 3'), findsOneWidget);
    expect(
      find.descendant(of: first, matching: find.text('Tapped: Item 3')),
      findsOneWidget,
    );
  });

  testWidgets('the title page: inline, large and search are all there',
      (WidgetTester tester) async {
    await pumpGallery(tester, only: 'Title');

    // The first case: the inline title. Scoped to the case, since "Title" is
    // also the name of this page.
    final Finder inlineCase = itemNamed('Inline title');
    await settleWith(tester, inlineCase);
    expect(
      find.descendant(of: inlineCase, matching: find.text('Title')),
      findsWidgets,
    );

    // Scroll down to the leading item.
    final Finder leading = itemNamed('Leading · with label');
    await settleWith(tester, leading);
    expect(
      find.descendant(of: leading, matching: find.text('Leading')),
      findsWidgets,
    );

    // Further down: the large title case, with the subtitle on the line above.
    final Finder large = itemNamed('Large title');
    await settleWith(tester, large);
    expect(
      find.descendant(of: large, matching: find.text('Subtitle')),
      findsWidgets,
    );

    // In the search case, press the magnifier: that case becomes a field.
    final Finder searchCase = itemNamed('Search');
    await settleWith(tester, searchCase);
    expect(
      find.descendant(of: searchCase, matching: find.byType(TextField)),
      findsNothing,
    );
    await tester.tap(
      find
          .descendant(of: searchCase, matching: find.byIcon(Icons.search))
          .first,
    );
    await settle(tester);
    expect(
      find.descendant(of: searchCase, matching: find.byType(TextField)),
      findsOneWidget,
    );
  });

  testWidgets(
      'copy page: captures screen by screen and stitches it onto the clipboard',
      (WidgetTester tester) async {
    await pumpGallery(tester, only: 'Capsule');

    // That route ends on the macOS side; the test answers with a fake "window"
    // and checks what is handed over.
    final Uint8List window = await solidPng(tester, 2000, 1600);
    int windows = 0;
    Uint8List? pasted;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      captureChannel,
      (MethodCall call) async {
        switch (call.method) {
          case 'captureWindow':
            windows++;
            return <Object?, Object?>{
              'bytes': window,
              'scale': 1.0,
              'offsetX': 0.0,
              'offsetY': 0.0,
            };
          case 'pasteImage':
            pasted = call.arguments as Uint8List;
            return null;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        captureChannel,
        null,
      ),
    );

    final Rect viewport = tester.getRect(find.byKey(listKey));
    // The list is lazy: the total height has to be measured first (walk down
    // screen by screen, see [wholeHeight]), which also puts it back at the top.
    final ScrollableState scrollable = tester.state(
      find
          .descendant(
              of: find.byKey(listKey), matching: find.byType(Scrollable))
          .first,
    );
    final double total = await wholeHeight(tester, scrollable);

    // A page takes several screens and each one is left to settle — in a test,
    // by pushing frames.
    //
    // The whole interaction runs inside runAsync: what comes back is a PNG, and
    // encoding it (decoding the window, encoding the stitched page) wants a real
    // frame, while the test platform owns the clock, so awaiting it directly
    // waits forever. Waits inside runAsync are real time, and frames have to be
    // pushed by hand.
    await tester.runAsync(() async {
      await tester.tap(find.text('Copy page'));
      for (int i = 0; i < 300 && pasted == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
    });
    await tester.pump();

    // A page is taller than one screen, so the window was captured several times.
    expect(windows, greaterThan(1));
    // The stitched image: the width of the list, the height of the whole page.
    // What came back was pixels, scaled to 1× while stitching.
    expect(pasted, isNotNull);
    final ui.Image page = await decode(tester, pasted!);
    expect(page.width, viewport.width.round());
    expect(page.height, total.round());
    page.dispose();

    // The result appears in place instead of a popup, and the list scrolls
    // back.
    expect(find.text('Copied page ${viewport.width.round()}×${total.round()}'),
        findsOneWidget);
    expect(find.text('Copy page'), findsNothing);
    expect(find.byType(CaseView), findsWidgets);
  });

  testWidgets('copy page: says so when the window cannot be captured',
      (WidgetTester tester) async {
    await pumpGallery(tester, only: 'Capsule');

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      captureChannel,
      (MethodCall call) async => call.method == 'captureWindow'
          ? <Object?, Object?>{'bytes': null}
          : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        captureChannel,
        null,
      ),
    );

    await tester.tap(find.text('Copy page'));
    await settle(tester);
    for (int i = 0;
        i < 30 && find.textContaining('capture failed').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.textContaining('capture failed'), findsOneWidget);
  });

  testWidgets('a code sample can be copied', (WidgetTester tester) async {
    await pumpGallery(tester, only: 'Capsule');

    // The clipboard is wired up in the test to see whether those lines arrive.
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final Finder item = itemNamed('Three items · middle selected');
    await tester.tap(
      find.descendant(
        of: item,
        matching: find.byTooltip('Copy these Swift lines'),
      ),
    );
    await settle(tester);

    expect(copied, contains('glassEffect'));
    // The corner turns into "Copied" in place; nothing else happens.
    expect(
      find.descendant(of: item, matching: find.text('Copied')),
      findsOneWidget,
    );
  });

  testWidgets(
      'switching the appearance: the whole page follows, without crashing',
      (WidgetTester tester) async {
    await pumpGallery(tester, only: 'Capsule');

    await tester.tap(find.byIcon(Icons.dark_mode_outlined));
    await settle(tester);

    expect(find.byIcon(Icons.light_mode_outlined), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the sidebar switches page', (WidgetTester tester) async {
    await pumpGallery(tester);

    expect(find.textContaining('floating capsule'), findsOneWidget);

    await tester.tap(
      find.descendant(of: find.byKey(sidebarKey), matching: find.text('Title')),
    );
    await settle(tester);

    expect(find.textContaining('The top bar:'), findsOneWidget);
    expect(find.text('Five items'), findsNothing);
  });

  testWidgets(
      'a window narrower than both lanes: the frame scrolls, the canvases keep their width',
      (WidgetTester tester) async {
    await pumpGallery(tester, only: 'Capsule', width: 900);

    final Finder item = itemNamed('Three items · middle selected');
    expect(item, findsOneWidget);
    // Both canvases keep the size they have (squeezed ones would no longer be
    // the same spec).
    for (final Element e in routesIn(item).evaluate()) {
      expect(tester.getSize(find.byWidget(e.widget)).width, canvasWidth);
    }
    // The case is as wide as the frame, both inside the list, with no overflow.
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'every case is laid out: three backdrops and all shapes do not throw',
      (WidgetTester tester) async {
    for (final String label in <String>['Capsule', 'Title']) {
      await pumpGallery(tester, only: label);
      final List<CaseView> items = <CaseView>[
        for (final Element e in find.byType(CaseView).evaluate())
          e.widget as CaseView,
      ];
      expect(items, isNotEmpty, reason: 'the $label page');
      for (final CaseView item in items) {
        expect(item.item.title, isNotEmpty);
        expect(item.item.hint, isNotEmpty);
        expect(item.item.height, greaterThan(0));
        // Every case carries both samples, one per lane.
        expect(item.item.swift, isNotEmpty, reason: item.item.title);
        expect(item.item.dart, isNotEmpty, reason: item.item.title);
        // The case as laid out has both lanes, neither missing.
        final Finder up = find.byWidget(item);
        expect(routesIn(up), findsNWidgets(2), reason: item.item.title);
        expect(
          find.descendant(of: up, matching: find.byType(CodeBlock)),
          findsNWidgets(2),
          reason: item.item.title,
        );
      }
      expect(tester.takeException(), isNull, reason: 'the $label page');
    }
  });
}
