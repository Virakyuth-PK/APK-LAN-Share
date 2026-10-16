import 'dart:async';
import 'dart:io';

import 'package:apk_lan_share_backend/apk_share_server.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/share_models.dart';

/// Runs the share server inside the phone and exposes its state to the UI.
///
/// Other devices join this phone's hotspot (or the same Wi-Fi), open
/// `http://<phone-ip>:<port>/get` and download the staged APKs.
class HostController extends ChangeNotifier {
  static const _channel = MethodChannel('apk_lan_share/native');
  static const int basePort = 8080;

  ApkShareServer? _server;
  Timer? _timer;

  bool running = false;
  bool starting = false;
  String? error;

  List<LanAddress> addresses = const [];
  String? selectedIp;
  List<HostedFile> files = const [];
  List<DownloadEvent> downloads = const [];

  /// 0..1 while an APK is being copied into app storage, else null.
  double? importProgress;
  String? importName;

  int get port => _server?.port ?? basePort;

  /// Address of the phone's own hotspot, when one is up.
  LanAddress? get hotspot {
    for (final address in addresses) {
      if (isHotspotInterface(address.name)) return address;
    }
    return null;
  }

  String? get origin => selectedIp == null ? null : 'http://$selectedIp:$port';

  /// Page other devices open. Lists every staged APK.
  String? get pageUrl => origin == null ? null : '$origin/get';

  int get activeDownloads => downloads.where((d) => d.isDownloading).length;

  Future<void> start() async {
    if (running || starting) return;
    starting = true;
    error = null;
    notifyListeners();

    try {
      final base = await getApplicationSupportDirectory();
      final dir = p.join(base.path, 'apks');
      for (var offset = 0; offset < 10; offset++) {
        final server = ApkShareServer(
          ServerConfig(port: basePort + offset, storageDir: dir),
        );
        try {
          await server.start();
          _server = server;
          break;
        } on SocketException {
          continue; // Port taken, try the next one.
        }
      }
      if (_server == null) {
        throw StateError('No free port between $basePort and ${basePort + 9}.');
      }
      running = true;
      await _refresh();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
      await _native('startService', {'text': 'Open $pageUrl'});
    } catch (e) {
      error = '$e';
    }
    starting = false;
    notifyListeners();
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _server?.stop();
    _server = null;
    running = false;
    downloads = const [];
    await _native('stopService');
    notifyListeners();
  }

  Future<void> toggle() => running ? stop() : start();

  void selectIp(String ip) {
    selectedIp = ip;
    _server?.useLanIp(ip);
    notifyListeners();
  }

  Future<bool> openHotspotSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openHotspotSettings') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Lets the user pick APKs and copies them into the served folder.
  Future<void> pickAndAdd() async {
    final server = _server;
    if (server == null || importProgress != null) return;
    final picked = await FilePicker.pickFiles(
      dialogTitle: 'Select APKs to share',
      type: FileType.any,
    );
    for (final file in picked) {
      final name = sanitizeFileName(file.name);
      if (name == null || file.path == null) {
        error = '"${file.name}" is not an .apk file.';
        notifyListeners();
        continue;
      }
      final source = File(file.path!);
      await _import(source, name, source.lengthSync(), server);
    }
    await _refresh();
  }

  Future<void> _import(
    File source,
    String name,
    int size,
    ApkShareServer server,
  ) async {
    error = null;
    importName = name;
    importProgress = 0;
    notifyListeners();

    final target = File(p.join(server.storagePath, name));
    final part = File('${target.path}.part');
    var copied = 0;
    try {
      final sink = part.openWrite();
      await for (final chunk in source.openRead()) {
        sink.add(chunk);
        copied += chunk.length;
        importProgress = size > 0 ? (copied / size).clamp(0.0, 1.0) : null;
        notifyListeners();
      }
      await sink.close();
      await part.rename(target.path);
    } catch (e) {
      error = 'Could not add $name: $e';
      if (part.existsSync()) part.deleteSync();
    } finally {
      importProgress = null;
      importName = null;
      notifyListeners();
    }
  }

  Future<void> deleteFile(HostedFile file) async {
    final server = _server;
    if (server == null) return;
    final target = File(p.join(server.storagePath, file.name));
    if (target.existsSync()) target.deleteSync();
    await _refresh();
  }

  Future<void> _refresh() async {
    final server = _server;
    if (server == null) return;

    addresses = await listLanAddresses();
    if (addresses.isEmpty) {
      selectedIp = null;
    } else if (!addresses.any((a) => a.ip == selectedIp)) {
      selectedIp = addresses.first.ip;
      server.useLanIp(selectedIp!);
    }

    final dir = Directory(server.storagePath);
    final found = dir.existsSync()
        ? (dir
              .listSync()
              .whereType<File>()
              .where((f) => p.extension(f.path).toLowerCase() == '.apk')
              .toList()
            ..sort(
              (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
            ))
        : <File>[];
    files = [
      for (final f in found)
        HostedFile(
          name: p.basename(f.path),
          size: f.lengthSync(),
          uploadedAt: f.lastModifiedSync(),
          downloadPath: '/download/${Uri.encodeComponent(p.basename(f.path))}',
        ),
    ];
    downloads = [
      for (final d in server.downloads.toJson())
        DownloadEvent.fromJson(d.cast<String, dynamic>()),
    ];
    notifyListeners();
  }

  Future<void> _native(String method, [Object? args]) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on PlatformException {
      // Background keep-alive is best effort.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _server?.stop();
    super.dispose();
  }
}
