// The capture server for this page: the outside asks, this answers.
//
// It only listens while the page runs with `--dart-define=capture_port=7777`
// (0, the default, listens on no port at all). The window route only exists on
// the macOS side (`macos/Runner/MainFlutterWindow.swift`).
//
//   GET /health                                whether the page is up, how many pages, whether window capture works
//   GET /pages                                 page and case names (without the two code samples)
//   GET /shot?pages=Capsule[&item=0-2][&crop=canvas][&appearance=dark]
//   GET /file/<id>                             that PNG
//   GET /quit                                  finish
//
// The answer is a small manifest (which captures, how large, where the two
// canvases are); the images themselves come from `/file/<id>`, so a whole-page
// image's bytes do not travel on this route. The manifest carries names and
// sizes only: the two code samples of a case go neither into an image nor into
// the manifest.
//
// One job at a time: capturing a page really does scroll the case list, and two
// jobs mixed together would measure a false total height.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../gallery/gallery_stage.dart';
import '../gallery/glass_case.dart';
import 'capture_targets.dart';
import 'page_capture.dart';

/// The capture server for this page.
class CaptureServer {
  CaptureServer(this.stage);

  /// The gallery as it is right now (handed over by the gallery in
  /// `gallery_app.dart`).
  final GalleryStage stage;

  /// The images to hand back (id to bytes). Only the most recent few are kept:
  /// they are fetched right after being captured and are not needed again.
  final Map<String, Uint8List> _blobs = <String, Uint8List>{};

  /// How many images to keep.
  static const int _keep = 32;

  /// One job after another.
  Future<void> _queue = Future<void>.value();

  /// Binds to this page. Throws if it cannot (the port is taken, say), and the
  /// caller says so.
  Future<HttpServer> start(int port) async {
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      port,
    );
    server.listen(_answer);
    return server;
  }

  Future<void> _answer(HttpRequest request) async {
    final String path = request.uri.path;
    try {
      if (path == '/health') return await _health(request);
      if (path == '/pages') return await _pages(request);
      if (path == '/shot') return await _capture(request);
      if (path == '/quit') return await _quit(request);
      if (path.startsWith('/file/')) {
        // An id carries the page name, so this path segment arrives
        // percent-encoded and has to be decoded.
        return await _file(
          request,
          Uri.decodeComponent(path.substring('/file/'.length)),
        );
      }
      await _say(request, HttpStatus.notFound, 'no such route: $path');
    } on FormatException catch (error) {
      await _say(request, HttpStatus.badRequest, error.message);
    } catch (error) {
      await _say(request, HttpStatus.internalServerError, '$error');
    }
  }

  /// Whether the page is up, how many pages there are, whether window capture
  /// works.
  Future<void> _health(HttpRequest request) async {
    bool window = true;
    String? note;
    try {
      final WindowImage image = await captureWindow();
      image.image.dispose();
    } on MissingPluginException {
      window = false;
      note = 'this platform has no window capture channel';
    } catch (error) {
      window = false;
      note = '$error';
    }
    await _json(request, <String, Object?>{
      'ready': true,
      'window': window,
      if (note != null) 'windowNote': note,
      'now': <String, Object?>{
        'page': stage.pageLabels[stage.page],
        'dark': stage.dark,
      },
      'pages': stage.pageLabels,
    });
  }

  /// The page and case names. The two code samples of a case are not here —
  /// this route only exists to show which pages and cases there are.
  Future<void> _pages(HttpRequest request) async {
    final List<List<GlassCase>> all = stage.allCases;
    await _json(request, <String, Object?>{
      'pages': <Object?>[
        for (int i = 0; i < all.length; i++)
          <String, Object?>{
            'page': stage.pageLabels[i],
            'cases': <Object?>[
              for (int j = 0; j < all[i].length; j++)
                <String, Object?>{
                  'index': j,
                  'title': all[i][j].title,
                  'hint': all[i][j].hint,
                },
            ],
          },
      ],
    });
  }

  /// Captures: answers a small manifest, with the images served from
  /// `/file/<id>`.
  Future<void> _capture(HttpRequest request) async {
    final Map<String, String> query = request.uri.queryParameters;
    final List<String> labels = (query['pages'] ?? '')
        .split(',')
        .map((String each) => each.trim())
        .where((String each) => each.isNotEmpty)
        .toList();
    final List<int> items = _items(query['item']);
    final String asked = (query['crop'] ?? '').trim();
    final String appearance = (query['appearance'] ?? 'light').trim();
    // How long to wait before capturing, in milliseconds. The system renders
    // the window later than the Dart side, and waiting too little captures a
    // frame that is not finished.
    final int settle = int.tryParse((query['settle'] ?? '').trim()) ?? 500;
    if (settle < 0 || settle > 10000) {
      throw const FormatException('settle is milliseconds, 0 to 10000');
    }
    // A burst: one capture at each of these milliseconds, measuring that one
    // change's transition.
    final String burst = (query['burst'] ?? '').trim();
    final List<int> offsets = burst.isEmpty
        ? const <int>[]
        : burst
            .split(',')
            .map((String each) => int.parse(each.trim()))
            .toList();
    if (burst.isNotEmpty && (offsetOutOfRange(offsets))) {
      throw const FormatException(
          'burst is a list of milliseconds such as 0,60,120,240 '
          '(0 to 10000 each, at most 12)');
    }
    final String askedTrigger = (query['trigger'] ?? 'appearance').trim();
    final BurstTrigger trigger = switch (askedTrigger) {
      'appearance' => BurstTrigger.appearance,
      'mount' => BurstTrigger.mount,
      _ => throw FormatException(
          'unknown trigger: $askedTrigger (appearance / mount)'),
    };

    final CaptureCrop crop = switch (asked) {
      'page' => CaptureCrop.page,
      'item' => CaptureCrop.item,
      'canvas' => CaptureCrop.canvas,
      // No crop named: naming items asks for their blocks, not naming any asks
      // for the whole page.
      '' => items.isEmpty ? CaptureCrop.page : CaptureCrop.item,
      _ => throw FormatException('unknown crop: $asked (page / item / canvas)'),
    };
    if (crop == CaptureCrop.page && items.isNotEmpty) {
      throw const FormatException(
          'a whole-page capture takes no items: use crop=item or crop=canvas '
          'for one block per case');
    }
    if (appearance != 'light' && appearance != 'dark') {
      throw FormatException('unknown appearance: $appearance (light / dark)');
    }

    final List<int> pages = labels.isEmpty
        ? <int>[for (int i = 0; i < stage.pageLabels.length; i++) i]
        : labels.map(stage.pageLabels.indexOf).toList();
    for (int i = 0; i < pages.length; i++) {
      if (pages[i] < 0) {
        throw FormatException(
            'no such page: ${labels[i]} (have ${stage.pageLabels})');
      }
    }

    final List<Object?> list = <Object?>[];
    for (final int page in pages) {
      final List<CaptureShot> captures = await _oneAtATime(
        () => captureCases(
          stage: stage,
          page: page,
          items: items,
          dark: appearance == 'dark',
          crop: crop,
          settleMs: settle,
          burst: offsets.isEmpty ? null : offsets,
          trigger: trigger,
        ),
      );
      for (final CaptureShot capture in captures) {
        final Uint8List? png = capture.png;
        if (png != null) {
          final String id = _id(capture.note);
          _keepBlob(id, png);
          capture.note['id'] = id;
          capture.note['file'] = '/file/$id';
        }
        list.add(capture.note);
      }
    }
    await _json(request, <String, Object?>{
      'shots': list,
      'out': 'http://127.0.0.1:${request.connectionInfo?.localPort}',
    });
  }

  /// That PNG.
  Future<void> _file(HttpRequest request, String id) async {
    final Uint8List? png = _blobs[id];
    if (png == null) {
      return _say(request, HttpStatus.notFound, 'no such capture: $id');
    }
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType('image', 'png')
      ..headers.set('cache-control', 'no-store')
      ..add(png);
    await request.response.close();
  }

  /// Finishes: the command that started this page uses it to wrap up.
  Future<void> _quit(HttpRequest request) async {
    await _json(request, <String, Object?>{'bye': true});
    await request.response.done;
    exit(0);
  }

  /// What one capture is called.
  ///
  /// Asking the same question twice replaces the same capture (an id is built
  /// from page, item, crop and appearance), so a caller saving by id overwrites
  /// the previous one instead of piling them up.
  String _id(Map<String, Object?> note) {
    final Object? index = note['index'];
    final Object? at = note['at'];
    return <Object?>[
      note['page'],
      index ?? 'page',
      note['crop'],
      note['dark'] == true ? 'dark' : 'light',
      if (at != null) 'at$at',
    ].join('-');
  }

  void _keepBlob(String id, Uint8List png) {
    _blobs.remove(id);
    _blobs[id] = png;
    while (_blobs.length > _keep) {
      _blobs.remove(_blobs.keys.first);
    }
  }

  /// One job after another: capturing a page really does scroll the case list,
  /// and two jobs mixed together would measure a false total height.
  Future<T> _oneAtATime<T>(Future<T> Function() job) {
    final Future<T> done = _queue.then((_) => job());
    _queue = done.then((_) {}, onError: (Object _) {});
    return done;
  }

  Future<void> _json(HttpRequest request, Object? body) async {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType =
          ContentType('application', 'json', charset: 'utf-8')
      ..add(utf8.encode('${jsonEncode(body)}\n'));
    await request.response.close();
  }

  Future<void> _say(HttpRequest request, int code, String said) async {
    request.response
      ..statusCode = code
      ..headers.contentType =
          ContentType('application', 'json', charset: 'utf-8')
      ..add(utf8.encode('${jsonEncode(<String, Object?>{'error': said})}\n'));
    await request.response.close();
    debugPrint('capture server: $code $said');
  }
}

/// Reads `item=0-2,5` as `[0, 1, 2, 5]`.
List<int> _items(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const <int>[];
  final List<int> picked = <int>[];
  for (final String part in raw.split(',')) {
    final String one = part.trim();
    if (one.isEmpty) continue;
    final int dash = one.indexOf('-');
    if (dash < 0) {
      picked.add(int.parse(one));
      continue;
    }
    final int from = int.parse(one.substring(0, dash));
    final int to = int.parse(one.substring(dash + 1));
    for (int i = from; i <= to; i++) {
      picked.add(i);
    }
  }
  return picked;
}

/// Whether a burst's offsets are acceptable: non-negative, within ten seconds,
/// at most 12 of them.
bool offsetOutOfRange(List<int> offsets) =>
    offsets.isEmpty ||
    offsets.length > 12 ||
    offsets.any((int each) => each < 0 || each > 10000);
