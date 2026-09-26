// Starts the page, captures what the command line asks for, and stops it again.
//
// This is the command for the "change a page, look at a page" loop: start the
// app in the background, wait for its capture server to answer, capture the
// places asked for into a directory, and stop it at the end. The images come
// back from the server the app itself opened (`lib/capture/capture_server.dart`),
// so one command can pin down a page, some cases and an appearance — nobody has
// to click, and nobody has to paste anything. A whole-page image's bytes do not
// squeeze into this command's output: it reports paths and sizes, and the files
// it wrote are there to look at.
//
//   dart run tool/capture.dart --start                         start (builds once if needed)
//   dart run tool/capture.dart --pages Capsule                 the capsule page, one whole-page image
//   dart run tool/capture.dart --pages Capsule --item 0,3 --crop canvas
//   dart run tool/capture.dart --pages Capsule,Title --appearance dark
//   dart run tool/capture.dart --pages Capsule --item 13 --settle 120   wait 120 ms before capturing
//   dart run tool/capture.dart --stop                          stop
//
// `--start` leaves the app in the background and returns: this command does not
// wait for it, so wrapping up is `--stop`.
//
// The port defaults to 7777, the same number `--start` writes into the
// `--dart-define`.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Where this command keeps its own things: the app log, the pid it recorded,
/// and the images it captured.
final Directory _home = Directory('/tmp/swiftui_kit_capture');

Future<void> main(List<String> argv) async {
  final _Args args = _Args(argv);
  try {
    if (args.flag('start')) return await _start(args);
    if (args.flag('stop')) return await _stop(args);
    await _fetch(args);
  } catch (error) {
    stderr.writeln('$error');
    exitCode = 1;
  }
}

/// Starts the page: builds once if needed, then puts that .app in the
/// background and waits for the server to say one word.
Future<void> _start(_Args args) async {
  final HttpClient client = _client();
  try {
    if (await _health(client, args) != null) {
      stdout.writeln('already running: ${args.at('/health')}');
      return;
    }
    final Directory example = _exampleDir();
    if (!args.flag('no-build')) {
      stdout.writeln('building once…');
      final Process build = await Process.start(
        'flutter',
        <String>[
          'build',
          'macos',
          '--debug',
          '--dart-define=capture_port=${args.port}',
        ],
        workingDirectory: example.path,
        mode: ProcessStartMode.inheritStdio,
      );
      final int code = await build.exitCode;
      if (code != 0) throw StateError('flutter build exited $code');
    }

    final String binary = '${example.path}/build/macos/Build/Products/Debug/'
        'swiftui_kit_example.app/Contents/MacOS/swiftui_kit_example';
    if (!File(binary).existsSync()) {
      throw StateError('executable not found: $binary');
    }
    final File log = File('${_home.path}/app.log');
    await _home.create(recursive: true);
    // The app cannot be this command's direct child: Dart waits until the whole
    // process tree it started is gone, and the app does not go away, so the
    // command would hang. A `sh` layer in between puts the app in the background
    // and exits (the app is then launchd's), with the app's output going to the
    // log rather than a pipe, so this command only waits for that `sh`.
    final Process launcher = await Process.start(
      'sh',
      <String>[
        '-c',
        r'"$0" </dev/null >> "$1" 2>&1 & echo $!',
        binary,
        log.path,
      ],
    );
    final String said =
        (await launcher.stdout.transform(utf8.decoder).join()).trim();
    await launcher.exitCode;
    final int? pid = int.tryParse(said);
    await File('${_home.path}/pid').writeAsString('${pid ?? ''}');

    for (int i = 0; i < 120; i++) {
      final Map<String, Object?>? health = await _health(client, args);
      if (health != null) {
        stdout.writeln('up: pid $pid, server ${args.at('/health')}');
        stdout.writeln(
          health['window'] == true
              ? 'window capture works.'
              : 'window capture does not work: ${health['windowNote']}',
        );
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    throw StateError(
        'it is up but the server does not answer: see ${log.path}');
  } finally {
    client.close(force: true);
  }
}

/// Stops it: asks the app to finish, then cleans up the recorded pid.
Future<void> _stop(_Args args) async {
  final HttpClient client = _client();
  try {
    if (await _health(client, args) == null) {
      stdout.writeln(
          'the server does not answer: the page is probably not running.');
    } else {
      try {
        await _askJson(client, args.at('/quit'));
      } on Object {
        // Whether the finishing line comes back complete does not matter: the
        // process is already gone.
      }
      stdout.writeln('asked it to finish: ${args.at('/health')}');
    }
  } finally {
    client.close(force: true);
  }

  final File pid = File('${_home.path}/pid');
  if (!pid.existsSync()) return;
  final int? id = int.tryParse(pid.readAsStringSync().trim());
  if (id != null && Process.killPid(id, ProcessSignal.sigterm)) {
    stdout.writeln('killed pid $id.');
  }
  pid.deleteSync();
}

/// Captures: asks the server for a manifest, then fetches each image on it into
/// the output directory.
Future<void> _fetch(_Args args) async {
  final HttpClient client = _client();
  try {
    if (await _health(client, args) == null) {
      throw StateError(
          'the page is not running: run dart run tool/capture.dart --start first');
    }
    final Map<String, Object?> answer = await _askJson(client, args.capture());
    if (args.flag('json')) {
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(answer));
    }
    final List<Object?> captures = answer['shots']! as List<Object?>;
    final Directory out = Directory(args.out);
    await out.create(recursive: true);
    int taken = 0;
    for (final Object? each in captures) {
      final Map<String, Object?> entry = each! as Map<String, Object?>;
      final Object? refused = entry['error'];
      if (refused != null) {
        stdout.writeln('${_line(entry)} — not captured: $refused');
        continue;
      }
      final String id = entry['id']! as String;
      final Uint8List png = await _askBytes(client, args.at('/file/$id'));
      final File file = File('${out.path}/$id.png');
      await file.writeAsBytes(png);
      taken++;
      stdout.writeln('${_line(entry)}  ${file.path}  ${png.length} bytes');
    }
    stdout.writeln('captured $taken images into ${out.path}');
  } finally {
    client.close(force: true);
  }
}

/// One line about one image: what it is and how large.
String _line(Map<String, Object?> entry) {
  final List<Object?> points =
      entry['points'] as List<Object?>? ?? const <Object?>[];
  final List<Object?> pixels =
      entry['pixels'] as List<Object?>? ?? const <Object?>[];
  final Object? index = entry['index'];
  final String said = <String>[
    '${entry['page']}',
    if (index != null) '#$index' else 'whole page',
    '${entry['title']}',
    '${entry['crop']}',
    entry['dark'] == true ? 'dark' : 'light',
    if (points.length == 2) '${points[0]}×${points[1]} pt',
    if (pixels.length == 2) '${pixels[0]}×${pixels[1]} px',
  ].join(' · ');
  return entry['fits'] == false
      ? '$said (part of it is outside the window)'
      : said;
}

HttpClient _client() =>
    HttpClient()..connectionTimeout = const Duration(seconds: 5);

/// Whether the server is there: if it is, reads back its `/health`.
Future<Map<String, Object?>?> _health(HttpClient client, _Args args) async {
  try {
    return await _askJson(client, args.at('/health'));
  } on Object {
    return null;
  }
}

Future<Map<String, Object?>> _askJson(HttpClient client, Uri uri) async {
  final HttpClientResponse response = await (await client.getUrl(uri)).close();
  final String body = await response.transform(utf8.decoder).join();
  if (response.statusCode != HttpStatus.ok) {
    throw StateError('$uri answered ${response.statusCode}: $body');
  }
  return jsonDecode(body) as Map<String, Object?>;
}

Future<Uint8List> _askBytes(HttpClient client, Uri uri) async {
  final HttpClientResponse response = await (await client.getUrl(uri)).close();
  if (response.statusCode != HttpStatus.ok) {
    final String body = await response.transform(utf8.decoder).join();
    throw StateError('$uri answered ${response.statusCode}: $body');
  }
  final List<int> bytes = <int>[];
  await for (final List<int> part in response) {
    bytes.addAll(part);
  }
  return Uint8List.fromList(bytes);
}

/// The directory this command lives in, one level up (`example/`).
Directory _exampleDir() => File.fromUri(Platform.script).parent.parent;

/// The command line.
class _Args {
  _Args(this._argv);

  final List<String> _argv;

  bool flag(String name) => _argv.contains('--$name');

  String? value(String name) {
    final int at = _argv.indexOf('--$name');
    if (at < 0 || at + 1 >= _argv.length) return null;
    return _argv[at + 1];
  }

  int get port => int.tryParse(value('port') ?? '') ?? 7777;

  String get out => value('out') ?? _home.path;

  Uri at(String path) => Uri.parse('http://127.0.0.1:$port$path');

  /// The capture request: whatever was given is asked for, and whatever was not
  /// is left to the server's defaults.
  Uri capture() => at('/shot').replace(
        queryParameters: <String, String>{
          if (value('pages') != null) 'pages': value('pages')!,
          if (value('item') != null) 'item': value('item')!,
          if (value('crop') != null) 'crop': value('crop')!,
          if (value('appearance') != null) 'appearance': value('appearance')!,
          if (value('settle') != null) 'settle': value('settle')!,
        },
      );
}
