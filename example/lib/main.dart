// Entry point of the swiftui_kit example gallery.

import 'dart:io';

import 'package:flutter/material.dart';

import 'capture/capture_server.dart';
import 'gallery/gallery_app.dart';
import 'gallery/gallery_pages.dart';
import 'gallery/gallery_stage.dart';

void main() {
  runApp(
    GalleryApp(
      pages: _selectedPages(),
      // The capture server only opens with `--dart-define=capture_port=7777`;
      // without it no port is listened on.
      onStage:
          const int.fromEnvironment('capture_port') == 0 ? null : _serveCapture,
    ),
  );
}

/// Attaches the capture server, which the command outside (`tool/capture.dart`)
/// asks for images.
///
/// If it cannot bind it says so on the debug output — this route failing does
/// not stop the page from running.
void _serveCapture(GalleryStage stage) {
  const int port = int.fromEnvironment('capture_port');
  CaptureServer(stage).start(port).then(
        (HttpServer server) =>
            debugPrint('capture server: http://127.0.0.1:${server.port}'),
        onError: (Object error) =>
            debugPrint('capture server did not start: $error'),
      );
}

/// Shows a single page only.
///
/// Either way of naming it works: on desktop and mobile
/// `--dart-define=only=Capsule`, on the web `?only=Capsule`.
List<GalleryPage> _selectedPages() {
  const String fromDefine = String.fromEnvironment('only');
  final String only = fromDefine.isEmpty
      ? (Uri.base.queryParameters['only'] ?? '')
      : fromDefine;
  if (only.isEmpty) return allPages;
  final List<GalleryPage> picked =
      allPages.where((GalleryPage each) => each.label == only).toList();
  return picked.isEmpty ? allPages : picked;
}
