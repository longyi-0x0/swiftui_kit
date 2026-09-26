// The capture server: what is asked is what comes back.
//
// These tests run on the test platform with the window route wired up (a fake
// whole-window image), so what they pin is what the server answers: which pages
// and cases there are, which parameters it refuses, how large a whole page and
// a single case's block are, that an image can be fetched from `/file/<id>`,
// and that the manifest never carries a case's two code samples.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftui_kit_example/capture/capture_server.dart';
import 'package:swiftui_kit_example/capture/page_capture.dart';
import 'package:swiftui_kit_example/gallery/gallery_app.dart';
import 'package:swiftui_kit_example/gallery/gallery_pages.dart';
import 'package:swiftui_kit_example/gallery/gallery_stage.dart';

/// Settles, and swallows the errors from the fallback lane's first frame at a
/// narrow width.
Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  while (tester.takeException() != null) {}
}

/// Pumps a gallery, wires up the window route and attaches the capture server.
Future<HttpServer> serve(WidgetTester tester) async {
  // The test platform replaces HttpClient with a fake (answering empty to
  // everything), and this test needs to reach the local server for real.
  final HttpOverrides? was = HttpOverrides.current;
  HttpOverrides.global = null;
  addTearDown(() => HttpOverrides.global = was);

  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(1400, 1600);
  addTearDown(tester.view.reset);

  GalleryStage? stage;
  await tester.pumpWidget(
    GalleryApp(pages: allPages, onStage: (GalleryStage each) => stage = each),
  );
  await settle(tester);
  expect(stage, isNotNull, reason: 'the gallery should hand out its moment');

  final Uint8List window = await solid(tester, 2000, 1600);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    captureChannel,
    (MethodCall call) async => call.method == 'captureWindow'
        ? <Object?, Object?>{
            'bytes': window,
            'scale': 1.0,
            'offsetX': 0.0,
            'offsetY': 0.0,
          }
        : null,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      captureChannel,
      null,
    ),
  );

  final HttpServer http =
      (await tester.runAsync(() => CaptureServer(stage!).start(0)))!;
  addTearDown(() => http.close(force: true));
  return http;
}

/// A solid-colour PNG, standing in for "a captured window".
Future<Uint8List> solid(WidgetTester tester, int wide, int tall) async =>
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

/// Asks one thing and returns the status code and the JSON body.
Future<(int, Map<String, Object?>)> ask(
  WidgetTester tester,
  HttpServer http,
  String path,
) async =>
    (await tester.runAsync(() async {
      final HttpClient client = HttpClient();
      try {
        final HttpClientResponse response = await (await client.getUrl(
          Uri.parse('http://127.0.0.1:${http.port}$path'),
        ))
            .close();
        final String body = await response.transform(utf8.decoder).join();
        return (response.statusCode, jsonDecode(body) as Map<String, Object?>);
      } finally {
        client.close(force: true);
      }
    }))!;

/// Fetches one image.
Future<Uint8List> file(
  WidgetTester tester,
  HttpServer http,
  String id,
) async =>
    (await tester.runAsync(() async {
      final HttpClient client = HttpClient();
      try {
        final HttpClientResponse response = await (await client.getUrl(
          Uri.parse('http://127.0.0.1:${http.port}')
              .replace(path: '/file/${Uri.encodeComponent(id)}'),
        ))
            .close();
        expect(response.statusCode, HttpStatus.ok);
        final List<int> bytes = <int>[];
        await for (final List<int> part in response) {
          bytes.addAll(part);
        }
        return Uint8List.fromList(bytes);
      } finally {
        client.close(force: true);
      }
    }))!;

/// How many pixels that PNG has.
Future<ui.Image> decode(WidgetTester tester, Uint8List png) async =>
    (await tester.runAsync(() async {
      final ui.Codec codec = await ui.instantiateImageCodec(png);
      return (await codec.getNextFrame()).image;
    }))!;

/// The single entry in a manifest.
Map<String, Object?> only(Map<String, Object?> answer) {
  final List<Object?> captures = answer['shots']! as List<Object?>;
  expect(captures, hasLength(1));
  return captures.single! as Map<String, Object?>;
}

void main() {
  testWidgets(
      '/health: says whether this page is up and how many pages there are',
      (WidgetTester tester) async {
    final HttpServer http = await serve(tester);
    final (int code, Map<String, Object?> body) =
        await ask(tester, http, '/health');

    expect(code, HttpStatus.ok);
    expect(body['ready'], isTrue);
    expect(body['pages'], <Object?>['Capsule', 'Title']);
    // That route is wired up in the test, so this says it works; without that
    // side it would say why not.
    expect(body['window'], isTrue);
    await settle(tester);
  });

  testWidgets(
      '/pages: page and case names are there, and not the two code samples',
      (WidgetTester tester) async {
    final HttpServer http = await serve(tester);
    final (int code, Map<String, Object?> body) =
        await ask(tester, http, '/pages');

    expect(code, HttpStatus.ok);
    final List<Object?> pages = body['pages']! as List<Object?>;
    expect(pages, hasLength(2));
    final Map<String, Object?> first = pages.first! as Map<String, Object?>;
    expect(first['page'], 'Capsule');
    final List<Object?> cases = first['cases']! as List<Object?>;
    expect(cases, isNotEmpty);
    for (final Object? each in cases) {
      final Map<String, Object?> one = each! as Map<String, Object?>;
      expect(one['index'], isA<int>());
      expect(one['title'], isNotEmpty);
      expect(one['hint'], isNotEmpty);
      expect(one.containsKey('swift'), isFalse);
      expect(one.containsKey('dart'), isFalse);
    }
    // Not one character of a code sample travels on this route.
    final String text = jsonEncode(body);
    expect(text.contains('glassEffect'), isFalse);
    expect(text.contains('GlassCapsuleBar'), isFalse);
    await settle(tester);
  });

  testWidgets('/shot by default: one whole-page image of this page',
      (WidgetTester tester) async {
    final HttpServer http = await serve(tester);
    final (int code, Map<String, Object?> body) =
        await ask(tester, http, '/shot?pages=Capsule');

    expect(code, HttpStatus.ok);
    final Map<String, Object?> capture = only(body);
    expect(capture['page'], 'Capsule');
    expect(capture['crop'], 'page');
    expect(capture['title'], 'whole page');
    expect(capture['dark'], isFalse);
    // A whole page is stitched at 1× logical points, so points equal pixels.
    expect(capture['points'], capture['pixels']);

    final Uint8List png = await file(tester, http, capture['id']! as String);
    expect(png.length, greaterThan(0));
    final ui.Image image = await decode(tester, png);
    final List<Object?> points = capture['points']! as List<Object?>;
    expect(image.width, points[0]);
    expect(image.height, points[1]);
    image.dispose();
    await settle(tester);
  });

  testWidgets('/shot with items: one image each, cut to the two canvases',
      (WidgetTester tester) async {
    final HttpServer http = await serve(tester);
    final (int code, Map<String, Object?> body) =
        await ask(tester, http, '/shot?pages=Capsule&item=0&crop=canvas');

    expect(code, HttpStatus.ok);
    final Map<String, Object?> capture = only(body);
    expect(capture['crop'], 'canvas');
    expect(capture['index'], 0);
    expect(capture.containsKey('error'), isFalse);
    // The two canvases together: one lane is one canvas wide, with a 12 gap
    // between them.
    final List<Object?> points = capture['points']! as List<Object?>;
    expect(points[0], canvasWidth * 2 + 12);
    expect(capture['canvases'], hasLength(2));
    expect(capture['fits'], isTrue);

    final Uint8List png = await file(tester, http, capture['id']! as String);
    final ui.Image image = await decode(tester, png);
    expect(image.width, points[0]);
    expect(image.height, points[1]);
    image.dispose();
    await settle(tester);
  });

  testWidgets(
      '/shot with items and no crop: that case\'s block, taller than the two canvases',
      (WidgetTester tester) async {
    final HttpServer http = await serve(tester);
    final (int code, Map<String, Object?> answer) =
        await ask(tester, http, '/shot?pages=Capsule&item=0');
    expect(code, HttpStatus.ok);
    final Map<String, Object?> item = only(answer);
    expect(item['crop'], 'item');

    final (int _, Map<String, Object?> canvases) =
        await ask(tester, http, '/shot?pages=Capsule&item=0&crop=canvas');
    final List<Object?> tall = item['points']! as List<Object?>;
    final List<Object?> low = only(canvases)['points']! as List<Object?>;
    // That block also holds the headline above and the two samples below.
    expect(tall[1] as int, greaterThan(low[1] as int));
    expect(tall[0], low[0]);
    await settle(tester);
  });

  testWidgets('/shot with another appearance: both lanes switch together',
      (WidgetTester tester) async {
    final HttpServer http = await serve(tester);
    final (int code, Map<String, Object?> body) =
        await ask(tester, http, '/shot?pages=Capsule');
    expect(code, HttpStatus.ok);
    expect(only(body)['dark'], isFalse);

    final (int _, Map<String, Object?> dark) =
        await ask(tester, http, '/shot?pages=Capsule&appearance=dark');
    expect(only(dark)['dark'], isTrue);
    // The appearance is part of the id, so the two do not overwrite each other.
    expect(only(dark)['id'], isNot(only(body)['id']));
    await settle(tester);
  });

  testWidgets('unrecognised requests: one line back, not an image',
      (WidgetTester tester) async {
    final HttpServer http = await serve(tester);

    final (int page, Map<String, Object?> said) =
        await ask(tester, http, '/shot?pages=Capsule&crop=page&item=1');
    expect(page, HttpStatus.badRequest);
    expect(said['error'], contains('whole-page'));

    final (int noPage, Map<String, Object?> missing) =
        await ask(tester, http, '/shot?pages=nope');
    expect(noPage, HttpStatus.badRequest);
    expect(missing['error'], contains('no such page'));

    final (int crop, Map<String, Object?> weird) =
        await ask(tester, http, '/shot?crop=half');
    expect(crop, HttpStatus.badRequest);
    expect(weird['error'], contains('crop'));

    final (int nothing, Map<String, Object?> none) =
        await ask(tester, http, '/file/nope');
    expect(nothing, HttpStatus.notFound);
    expect(none['error'], contains('no such capture'));

    final (int badSettle, Map<String, Object?> tooLong) = await ask(
        tester, http, '/shot?pages=Capsule&item=0&crop=canvas&settle=99000');
    expect(badSettle, HttpStatus.badRequest);
    expect(tooLong['error'], contains('settle'));

    final (int burst, Map<String, Object?> many) = await ask(
      tester,
      http,
      '/shot?pages=Capsule&item=0&crop=canvas&burst=0,1,2,3,4,5,6,7,8,9,10,11,12,13',
    );
    expect(burst, HttpStatus.badRequest);
    expect(many['error'], contains('burst'));
    await settle(tester);
  });
}
