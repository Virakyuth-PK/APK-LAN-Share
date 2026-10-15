import 'dart:convert';
import 'dart:io';

import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'apk_meta.dart';
import 'download_page.dart';

/// Everything the companion server needs to run.
class ServerConfig {
  const ServerConfig({
    this.port = 8080,
    this.bindAddress = '0.0.0.0',
    this.storageDir = 'public',
    this.uiDir,
    this.maxUploadBytes = 4 * 1024 * 1024 * 1024, // 4 GB
  });

  /// TCP port to listen on.
  final int port;

  /// Interface to bind to. `0.0.0.0` accepts connections from the whole LAN.
  final String bindAddress;

  /// Directory where staged `.apk` files are written.
  final String storageDir;

  /// Optional directory containing the built Flutter web app.
  /// When present the dashboard itself is served from this port.
  final String? uiDir;

  /// Hard upload limit (bytes).
  final int maxUploadBytes;
}

/// HTTP companion for the APK LAN Share Flutter web UI.
///
/// Routes:
///   GET    /info                 -> JSON: LAN IP, port, storage dir, staged files
///   DELETE `/files/<file>.apk`      -> removes a staged APK
///   POST   `/upload?name=<file>.apk` -> raw request body is staged to disk
///   GET    `/download/<file>.apk`    -> streams a staged APK
///   GET    /                     -> Flutter web dashboard (if `uiDir` set)
///   OPTIONS *                    -> CORS preflight
class ApkShareServer {
  ApkShareServer(this.config);

  final ServerConfig config;

  HttpServer? _server;
  String _lanIp = '127.0.0.1';

  /// Absolute path of the staging directory.
  late final String storagePath = p.normalize(p.absolute(config.storageDir));

  /// Absolute path of the Flutter web build, if mounted.
  late final String? uiPath = config.uiDir == null
      ? null
      : p.normalize(p.absolute(config.uiDir!));

  /// The LAN IP reported to clients (detected at startup).
  String get lanIp => _lanIp;
  int get port => config.port;

  /// `http://<lan-ip>:<port>` — the base URL encoded into QR codes.
  String get baseUrl => 'http://$_lanIp:${config.port}';

  /// Whether the HTTP server is currently listening.
  bool get isRunning => _server != null;

  Future<HttpServer> start() async {
    Directory(storagePath).createSync(recursive: true);
    _lanIp = await detectLanIp();

    final handler = Pipeline()
        .addMiddleware(logRequests(logger: _logRequest))
        .addHandler(_handle);

    final server = await shelf_io.serve(
      handler,
      config.bindAddress == '0.0.0.0'
          ? InternetAddress.anyIPv4
          : config.bindAddress,
      config.port,
    );
    _server = server;
    return server;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  // --------------------------------------------------------------- routing

  Future<Response> _handle(Request request) async {
    final path = request.url.path;
    final method = request.method;

    if (method == 'OPTIONS') return _corsPreflight();

    Response response;
    if (method == 'GET' || method == 'HEAD') {
      final headOnly = method == 'HEAD';
      if (path == 'info') {
        response = _infoResponse();
      } else if (path.startsWith('get/')) {
        response = await _servePage(path.substring('get/'.length), headOnly);
      } else if (path.startsWith('icon/')) {
        response = await _serveIcon(path.substring('icon/'.length), headOnly);
      } else if (path.startsWith('download/')) {
        response = await _serveApk(
          path.substring('download/'.length),
          headOnly,
          request,
        );
      } else {
        response = await _serveUi(path, headOnly);
      }
    } else if (method == 'POST' && path == 'upload') {
      response = await _handleUpload(request);
    } else if (method == 'DELETE' && path.startsWith('files/')) {
      response = _deleteApk(path.substring('files/'.length));
    } else {
      response = _json(405, {
        'ok': false,
        'error': 'Method $method not allowed.',
      });
    }

    return _withCors(response);
  }

  // ----------------------------------------------------------------- info

  Response _infoResponse() => _json(200, {
    'ok': true,
    'app': 'APK LAN Share',
    'version': '1.0.0',
    'lanIp': _lanIp,
    'port': config.port,
    'baseUrl': baseUrl,
    'storageDir': storagePath,
    'servesUi': uiPath != null,
    'files': _stagedFiles().map(_fileJson).toList(),
  });

  List<File> _stagedFiles() {
    final dir = Directory(storagePath);
    if (!dir.existsSync()) return const [];
    final files =
        dir
            .listSync()
            .whereType<File>()
            .where((f) => p.extension(f.path).toLowerCase() == '.apk')
            .toList()
          ..sort(
            (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
          );
    return files;
  }

  Map<String, Object> _fileJson(File file) {
    final name = p.basename(file.path);
    return {
      'name': name,
      'size': file.lengthSync(),
      'uploadedAt': file.lastModifiedSync().toIso8601String(),
      'downloadPath': '/download/${Uri.encodeComponent(name)}',
    };
  }

  // -------------------------------------------------------------- upload

  Future<Response> _handleUpload(Request request) async {
    final rawName = request.url.queryParameters['name'] ?? '';
    final fileName = sanitizeFileName(rawName);
    if (fileName == null) {
      return _json(400, {
        'ok': false,
        'error':
            'Invalid file name "$rawName". Only plain .apk names are '
            'accepted.',
      });
    }

    final target = File(p.join(storagePath, fileName));
    final staging = File(
      p.join(
        storagePath,
        '.$fileName.${DateTime.now().microsecondsSinceEpoch}.part',
      ),
    );

    var received = 0;
    var overflow = false;
    IOSink? sink;
    try {
      sink = staging.openWrite();
      await for (final chunk in request.read()) {
        received += chunk.length;
        if (received > config.maxUploadBytes) {
          overflow = true;
          continue; // keep draining so shelf does not hang
        }
        if (!overflow) sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
      sink = null;
    } catch (error) {
      await sink?.close();
      if (staging.existsSync()) staging.deleteSync();
      return _json(500, {'ok': false, 'error': 'Upload failed: $error'});
    }

    if (overflow) {
      staging.deleteSync();
      final limitMb = config.maxUploadBytes ~/ (1024 * 1024);
      return _json(413, {
        'ok': false,
        'error': 'File exceeds the $limitMb MB limit.',
      });
    }
    if (received == 0) {
      staging.deleteSync();
      return _json(400, {'ok': false, 'error': 'Empty upload body.'});
    }

    staging.renameSync(target.path);

    return _json(200, {
      'ok': true,
      'file': _fileJson(target),
      'downloadUrl': '$baseUrl/download/${Uri.encodeComponent(fileName)}',
    });
  }

  // ------------------------------------------------------------ download

  Future<Response> _serveApk(
    String encodedName,
    bool headOnly,
    Request request,
  ) async {
    String name;
    try {
      name = Uri.decodeComponent(encodedName);
    } on FormatException {
      return _json(400, {'ok': false, 'error': 'Malformed file name.'});
    }

    final safe = sanitizeFileName(name);
    if (safe == null) {
      return _json(400, {'ok': false, 'error': 'Invalid file name.'});
    }

    final file = File(p.join(storagePath, safe));
    if (!file.existsSync()) {
      return _json(404, {
        'ok': false,
        'error':
            'No staged APK named "$safe". Stage it from the dashboard first.',
      });
    }

    return _fileResponse(
      file,
      contentType: 'application/vnd.android.package-archive',
      downloadName: safe,
      headOnly: headOnly,
      rangeHeader: request.headers['range'],
    );
  }

  /// Resolves a URL-encoded APK name to a staged file, or an error response.
  (File?, Response?) _resolveApk(String encodedName) {
    String name;
    try {
      name = Uri.decodeComponent(encodedName);
    } on FormatException {
      return (null, _json(400, {'ok': false, 'error': 'Malformed file name.'}));
    }
    final safe = sanitizeFileName(name);
    if (safe == null) {
      return (null, _json(400, {'ok': false, 'error': 'Invalid file name.'}));
    }
    final file = File(p.join(storagePath, safe));
    if (!file.existsSync()) {
      return (null, _notFoundPage(safe));
    }
    return (file, null);
  }

  /// Phone-friendly landing page the QR code points to.
  Future<Response> _servePage(String encodedName, bool headOnly) async {
    final (file, error) = _resolveApk(encodedName);
    if (error != null) return error;
    final meta = await readApkMeta(file!);
    final html = renderDownloadPage(
      fileName: p.basename(file.path),
      size: file.lengthSync(),
      uploadedAt: file.lastModifiedSync(),
      meta: meta,
    );
    return Response(
      200,
      body: headOnly ? null : html,
      headers: const {
        'content-type': 'text/html; charset=utf-8',
        'cache-control': 'no-store',
      },
    );
  }

  Future<Response> _serveIcon(String encodedName, bool headOnly) async {
    final (file, error) = _resolveApk(encodedName);
    if (error != null) return error;
    final icon = (await readApkMeta(file!)).iconPng;
    if (icon == null) return Response.notFound('');
    return Response(
      200,
      body: headOnly ? null : icon,
      headers: {
        'content-type': 'image/png',
        'content-length': '${icon.length}',
        'cache-control': 'no-store',
      },
    );
  }

  Response _notFoundPage(String name) => _html(
    404,
    renderMessagePage(
      'File not found',
      '"$name" is no longer on the server. Ask the sender to share it again.',
    ),
  );

  Response _deleteApk(String encodedName) {
    String name;
    try {
      name = Uri.decodeComponent(encodedName);
    } on FormatException {
      return _json(400, {'ok': false, 'error': 'Malformed file name.'});
    }
    final safe = sanitizeFileName(name);
    if (safe == null) {
      return _json(400, {'ok': false, 'error': 'Invalid file name.'});
    }
    final file = File(p.join(storagePath, safe));
    if (!file.existsSync()) {
      return _json(404, {'ok': false, 'error': 'No staged APK named "$safe".'});
    }
    file.deleteSync();
    return _json(200, {'ok': true, 'deleted': safe});
  }

  // ------------------------------------------------------------------ UI

  Future<Response> _serveUi(String path, bool headOnly) async {
    final root = uiPath;
    if (root == null || !Directory(root).existsSync()) {
      return _html(
        404,
        '<!doctype html><meta charset="utf-8"><title>APK LAN Share</title>'
        '<body style="font-family:system-ui;background:#0f1117;color:#e5e7eb;'
        'display:grid;place-items:center;height:100vh;margin:0">'
        '<div style="text-align:center;max-width:36rem;padding:2rem">'
        '<h1 style="font-size:1.35rem">Server running — dashboard not built yet</h1>'
        '<p style="color:#9ca3af">Run <code>flutter build web</code>, restart the '
        'server with <code>--ui build/web</code>, or start the dev server with '
        '<code>flutter run -d web-server --web-port 5000</code> and open that URL.'
        '</p></div></body>',
      );
    }

    var rel = path.isEmpty ? 'index.html' : p.normalize(path);
    if (rel.startsWith('..') || p.isAbsolute(rel)) {
      return _json(400, {'ok': false, 'error': 'Bad path.'});
    }

    var file = File(p.join(root, rel));
    if (!file.existsSync()) {
      final hasExtension = p.split(rel).last.contains('.');
      if (hasExtension) return _notFoundUi(rel);
      file = File(p.join(root, 'index.html'));
      if (!file.existsSync()) return _notFoundUi(rel);
    }

    final mime = lookupMimeType(file.path) ?? 'application/octet-stream';
    return _fileResponse(file, contentType: mime, headOnly: headOnly);
  }

  Response _notFoundUi(String rel) => _html(
    404,
    '<!doctype html><meta charset="utf-8"><title>404</title>'
    '<body style="font-family:system-ui;display:grid;place-items:center;'
    'height:100vh;margin:0">404 — <code>${_escapeHtml(rel)}</code> not found'
    '</body>',
  );

  // -------------------------------------------------------------- helpers

  Response _fileResponse(
    File file, {
    required String contentType,
    String? downloadName,
    bool headOnly = false,
    String? rangeHeader,
  }) {
    final length = file.lengthSync();
    final headers = <String, String>{
      'content-type': contentType,
      'accept-ranges': 'bytes',
      'content-length': '$length',
      'cache-control': 'no-store',
      'x-content-type-options': 'nosniff',
      if (downloadName != null)
        'content-disposition':
            'attachment; filename="${_asciiFallback(downloadName)}"',
    };
    if (headOnly) return Response(200, headers: headers);

    // Single-range support so phones can resume interrupted downloads.
    final range = rangeHeader == null
        ? null
        : RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(rangeHeader.trim());
    if (range != null) {
      final startText = range.group(1)!;
      final endText = range.group(2)!;
      int start;
      int end;
      if (startText.isEmpty) {
        final suffix = int.tryParse(endText) ?? 0;
        start = length - suffix;
        end = length - 1;
      } else {
        start = int.parse(startText);
        end = endText.isEmpty ? length - 1 : int.parse(endText);
      }
      if (start < 0) start = 0;
      if (end >= length) end = length - 1;
      if (length == 0 || start > end) {
        return Response(
          416,
          headers: {'content-range': 'bytes */$length', 'content-length': '0'},
        );
      }
      return Response(
        206,
        body: file.openRead(start, end + 1),
        headers: {
          ...headers,
          'content-length': '${end - start + 1}',
          'content-range': 'bytes $start-$end/$length',
        },
      );
    }
    return Response(200, body: file.openRead(), headers: headers);
  }

  String _asciiFallback(String name) =>
      name.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');

  Response _json(int status, Map<String, Object> body) => Response(
    status,
    body: jsonEncode(body),
    headers: const {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
    },
  );

  Response _html(int status, String body) => Response(
    status,
    body: body,
    headers: const {'content-type': 'text/html; charset=utf-8'},
  );

  Response _corsPreflight() => Response(
    204,
    headers: {
      'access-control-allow-origin': '*',
      'access-control-allow-methods': 'GET, HEAD, POST, DELETE, OPTIONS',
      'access-control-allow-headers':
          'Content-Type, Accept, Range, X-Requested-With, X-File-Name',
      'access-control-expose-headers':
          'Content-Length, Content-Disposition, Content-Type, Content-Range',
      'access-control-max-age': '86400',
      'content-length': '0',
      'cache-control': 'no-store',
    },
  );

  Response _withCors(Response response) => response.change(
    headers: const {
      'access-control-allow-origin': '*',
      'access-control-expose-headers':
          'Content-Length, Content-Disposition, Content-Type',
    },
  );

  void _logRequest(String message, bool isError) {
    final now = DateTime.now();
    final stamp = [
      now.hour.toString().padLeft(2, '0'),
      now.minute.toString().padLeft(2, '0'),
      now.second.toString().padLeft(2, '0'),
    ].join(':');
    stderr.writeln('[$stamp] ${isError ? 'ERROR ' : ''}$message');
  }
}

String _escapeHtml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// Accepts only safe, flat `.apk` file names. Returns `null` when rejected.
String? sanitizeFileName(String rawName) {
  var name = rawName.trim().replaceAll(r'\', '/');
  final lastSlash = name.lastIndexOf('/');
  if (lastSlash != -1) name = name.substring(lastSlash + 1);

  name = name.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');
  name = name.replaceAll(RegExp(r'^\.+'), '');
  if (name.isEmpty) return null;
  if (!name.toLowerCase().endsWith('.apk')) return null;
  if (name.length > 180) {
    name = '${name.substring(0, 176)}.apk';
  }
  return name;
}

/// Best-effort detection of this machine's LAN IPv4 address.
Future<String> detectLanIp() async {
  try {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      includeLinkLocal: false,
      type: InternetAddressType.IPv4,
    );

    final scored = <({int score, String ip})>[];
    for (final interface in interfaces) {
      final name = interface.name.toLowerCase();
      final penalty =
          name.contains('docker') ||
              name.contains('veth') ||
              name.contains('vmnet') ||
              name.contains('bridge') ||
              name.contains('vbox')
          ? 70
          : 0;
      for (final address in interface.addresses) {
        if (address.isLoopback || address.isLinkLocal) continue;
        final score = scoreIp(address.address) - penalty;
        if (score > 0) scored.add((score: score, ip: address.address));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    if (scored.isNotEmpty) return scored.first.ip;
  } catch (_) {
    // Fall through to loopback.
  }
  return '127.0.0.1';
}

int scoreIp(String ip) {
  if (ip.startsWith('192.168.')) return 100;
  if (ip.startsWith('10.')) return 90;
  final match = RegExp(r'^172\.(\d+)\.').firstMatch(ip);
  if (match != null) {
    final second = int.tryParse(match.group(1) ?? '') ?? 0;
    if (second >= 16 && second <= 31) return 80;
  }
  if (ip.startsWith('127.')) return 0;
  return 40;
}
