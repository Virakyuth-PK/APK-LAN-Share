import 'dart:async';
import 'dart:io';

import 'package:apk_lan_share_backend/apk_share_server.dart';

const _usage = '''
APK LAN Share — companion server

Usage:
  dart run bin/server.dart [options]

Options:
  --port <n>       Port to listen on (default: 8080)
  --host <addr>    Interface to bind (default: 0.0.0.0 = whole LAN)
  --dir <path>     Directory for staged APKs (default: ./public)
  --ui <path>      Serve the built Flutter web app from this directory
                   (default: auto-detects build/web or ../build/web)
  --no-ui          Never serve a UI, API routes only
  -h, --help       Show this help

Examples:
  dart run bin/server.dart
  dart run bin/server.dart --port 9090 --ui build/web
  dart run bin/server.dart --dir ~/Public/apks --no-ui
''';

Future<void> main(List<String> args) async {
  final parsed = _parseArgs(args);
  if (parsed == null) {
    stdout.write(_usage);
    exitCode = 64; // EX_USAGE
    return;
  }

  final config = parsed;

  stdout.writeln('');
  stdout.writeln('  APK LAN Share · companion server');
  stdout.writeln('  ─────────────────────────────────────────────');

  final server = ApkShareServer(config);
  try {
    await server.start();
  } on SocketException catch (error) {
    stderr.writeln('');
    stderr.writeln('  ✗ Could not bind ${config.bindAddress}:${config.port}');
    stderr.writeln('    ${error.message}');
    if (error.osError?.errorCode == 48 || error.osError?.errorCode == 10048) {
      stderr.writeln('    → Port already in use. Try: --port 8081');
    }
    stderr.writeln('');
    exitCode = 1;
    return;
  } catch (error) {
    stderr.writeln('');
    stderr.writeln('  ✗ Failed to start: $error');
    exitCode = 1;
    return;
  }

  final lan = server.lanIp;
  final port = server.port;
  stdout.writeln('  ✓ Listening on ${config.bindAddress}:$port');
  stdout.writeln('  ✓ LAN address   http://$lan:$port');
  stdout.writeln('  ✓ Staging dir   ${server.storagePath}');
  if (server.uiPath != null) {
    stdout.writeln(
      '  ✓ Dashboard     http://127.0.0.1:$port  (built Flutter web)',
    );
  } else {
    stdout.writeln(
      '  ! Dashboard     not mounted — run `flutter build web` and add --ui build/web',
    );
  }
  stdout.writeln('  ✓ CORS          enabled (Access-Control-Allow-Origin: *)');
  stdout.writeln('  ─────────────────────────────────────────────');
  stdout.writeln('  Upload endpoint:');
  stdout.writeln('    POST http://127.0.0.1:$port/upload?name=<file>.apk');
  stdout.writeln('  Download endpoint:');
  stdout.writeln('    GET  http://$lan:$port/download/<file>.apk');
  stdout.writeln('');
  stdout.writeln('  Leave this running. Press Ctrl+C to stop.');
  stdout.writeln('');

  final completer = Completer<void>();
  for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm]) {
    // sigterm is not available on Windows; guard for portability.
    try {
      signal.watch().listen((_) async {
        if (!completer.isCompleted) completer.complete();
      });
    } catch (_) {
      // Unsupported signal on this platform — ignore.
    }
  }

  await completer.future;
  stdout.writeln('\n  Stopping server…');
  await server.stop();
  exitCode = 0;
}

ServerConfig? _parseArgs(List<String> args) {
  var port = 8080;
  var host = '0.0.0.0';
  String? dir;
  String? ui;
  var uiExplicit = false;
  var noUi = false;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];

    String? next() {
      if (i + 1 >= args.length) {
        stderr.writeln('Missing value for $arg');
        return null;
      }
      return args[++i];
    }

    String? inlineValue(String flag) {
      final eq = arg.indexOf('=');
      return eq == -1 ? null : arg.substring(eq + 1);
    }

    if (arg == '-h' || arg == '--help') return null;
    if (arg == '--no-ui') {
      noUi = true;
      continue;
    }

    final name = arg.split('=').first;
    switch (name) {
      case '--port':
        {
          final value = inlineValue(arg) ?? next();
          final parsed = int.tryParse(value ?? '');
          if (parsed == null || parsed < 1 || parsed > 65535) {
            stderr.writeln('Invalid port: ${value ?? ''}');
            return null;
          }
          port = parsed;
        }
      case '--host':
        {
          final value = inlineValue(arg) ?? next();
          if (value == null || value.isEmpty) {
            stderr.writeln('Missing --host value');
            return null;
          }
          host = value;
        }
      case '--dir':
        {
          final value = inlineValue(arg) ?? next();
          if (value == null || value.isEmpty) {
            stderr.writeln('Missing --dir value');
            return null;
          }
          dir = value;
        }
      case '--ui':
        {
          final value = inlineValue(arg) ?? next();
          if (value == null || value.isEmpty) {
            stderr.writeln('Missing --ui value');
            return null;
          }
          ui = value;
          uiExplicit = true;
        }
      default:
        {
          if (arg.startsWith('-')) {
            stderr.writeln('Unknown option: $arg');
            return null;
          }
          stderr.writeln('Unexpected argument: $arg');
          return null;
        }
    }
  }

  if (noUi) {
    ui = null;
  } else if (!uiExplicit) {
    ui = _autoDetectUiDir();
  }

  return ServerConfig(
    port: port,
    bindAddress: host,
    storageDir: dir ?? 'public',
    uiDir: ui,
  );
}

/// Looks for `flutter build web` output relative to the working directory.
String? _autoDetectUiDir() {
  for (final candidate in [
    'build/web',
    '../build/web',
    'apk-lan-share/build/web',
  ]) {
    final dir = Directory(candidate);
    if (dir.existsSync() && File('$candidate/index.html').existsSync()) {
      return candidate;
    }
  }
  return null;
}
