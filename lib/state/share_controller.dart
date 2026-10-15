import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/share_models.dart';
import '../services/share_api.dart';
import '../util/formatters.dart';

/// Single source of truth for the dashboard.
///
/// Deliberately self-contained: plain `ChangeNotifier` + `ListenableBuilder`,
/// no external state-management package.
class ShareController extends ChangeNotifier {
  /// Fallback port when nothing else is known.
  static const int defaultPort = 8080;

  /// Newest-first activity log (capped).
  final List<LogEntry> logs = <LogEntry>[];

  // --- connection ---------------------------------------------------------
  ShareApi? _api;
  bool connected = false;
  bool connecting = false;
  BackendInfo? backend;

  /// LAN IP used to build QR/download URLs (auto-detected unless overridden).
  String host = '';
  int port = defaultPort;
  bool hostOverridden = false;

  // --- staging ------------------------------------------------------------
  ShareStage stage = ShareStage.idle;
  double progress = 0;
  HostedFile? staged;
  String? failureMessage;
  String? activeFileName;
  int? activeFileSize;

  /// True while a file is dragged over the page.
  bool dragging = false;

  void setDragging(bool value) {
    if (value && busy) return;
    if (dragging == value) return;
    dragging = value;
    notifyListeners();
  }

  /// Handles a file released anywhere on the page.
  Future<void> dropFile(String fileName, Uint8List bytes) async {
    if (busy) return;
    if (!fileName.toLowerCase().endsWith('.apk')) {
      addLog('Ignored drop — only .apk files can be shared.', LogKind.error);
      return;
    }
    await stageFile(fileName: fileName, bytes: bytes);
  }

  /// True while a file is being read or uploaded.
  bool get busy => stage == ShareStage.reading || stage == ShareStage.uploading;

  /// Origin other devices reach this machine on (never `127.0.0.1`).
  String get shareOrigin => 'http://${host.isEmpty ? '127.0.0.1' : host}:$port';

  /// Direct APK download URL.
  String? get downloadUrl =>
      staged == null ? null : '$shareOrigin${staged!.downloadPath}';

  /// Landing page encoded into the QR code: app details + download button.
  String? get pageUrl {
    if (staged == null) return null;
    if (shareAll && files.length > 1) return '$shareOrigin/get';
    return '$shareOrigin/get/${Uri.encodeComponent(staged!.name)}';
  }

  ShareController() {
    addLog(
      'Dashboard ready — looking for the companion backend…',
      LogKind.info,
    );
  }

  // --- connection ---------------------------------------------------------

  /// Tries `127.0.0.1:<port>` first, then the page origin (covers the
  /// single-port deployment where the backend serves this UI).
  Future<void> connect({bool verbose = true}) async {
    if (connecting) return;
    connecting = true;
    if (verbose) {
      addLog('Scanning for the companion backend on port $port…', LogKind.info);
    } else {
      notifyListeners();
    }

    final candidates = <String>['http://127.0.0.1:$port'];
    final pageOrigin = _pageOrigin();
    if (pageOrigin != null && !candidates.contains(pageOrigin)) {
      candidates.add(pageOrigin);
    }

    for (final candidate in candidates) {
      try {
        final api = ShareApi(candidate);
        final info = await api.fetchInfo();
        _api?.dispose();
        _api = api;
        backend = info;
        connected = true;
        port = info.port;
        if (!hostOverridden) host = info.lanIp;
        _restorePreviousSession(info);
        _startPolling();
        if (verbose) {
          addLog('Backend online — ${info.baseUrl}', LogKind.success);
        }
        connecting = false;
        notifyListeners();
        return;
      } catch (_) {
        // Try the next candidate.
      }
    }

    _api?.dispose();
    _api = null;
    connected = false;
    backend = null;
    if (verbose) {
      addLog(
        'Backend not reachable on port $port. Start it with:\n'
        'cd backend && dart run bin/server.dart --port $port',
        LogKind.error,
      );
    }
    connecting = false;
    notifyListeners();
  }

  /// Re-applies values typed into the connection panel and reconnects.
  Future<void> applyConnection({
    required String hostInput,
    required String portInput,
  }) async {
    final parsedPort = int.tryParse(portInput.trim());
    if (parsedPort == null || parsedPort < 1 || parsedPort > 65535) {
      addLog('Port must be a number between 1 and 65535.', LogKind.error);
      return;
    }

    port = parsedPort;
    final trimmedHost = hostInput.trim();
    hostOverridden = trimmedHost.isNotEmpty;
    host = trimmedHost;
    connected = false;
    _api?.dispose();
    _api = null;
    notifyListeners();

    await connect();
  }

  String? _pageOrigin() {
    try {
      final origin = Uri.base.origin;
      return origin.startsWith('http') ? origin : null;
    } catch (_) {
      return null;
    }
  }

  void _restorePreviousSession(BackendInfo info) {
    if (info.files.isEmpty) return;
    if (staged != null) return;
    staged = info.files.first;
    stage = ShareStage.ready;
    progress = 1;
    activeFileName = staged!.name;
    activeFileSize = staged!.size;
    addLog(
      'Found ${info.files.length} APK(s) already staged — restored '
      '${staged!.name}',
      LogKind.success,
    );
  }

  // --- staging ------------------------------------------------------------

  /// Reads [bytes] and streams them to the backend, surfacing progress.
  Future<void> stageFile({
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (busy) return;
    failureMessage = null;

    if (!fileName.toLowerCase().endsWith('.apk')) {
      _fail('Only .apk files can be shared — "$fileName" was skipped.');
      return;
    }
    if (bytes.isEmpty) {
      _fail('"$fileName" is empty (0 bytes).');
      return;
    }

    activeFileName = fileName;
    activeFileSize = bytes.length;
    stage = ShareStage.reading;
    progress = 0.04;
    addLog('Reading ${formatBytes(bytes.length)} — $fileName…', LogKind.info);

    if (!connected || _api == null) {
      await connect(verbose: false);
      if (!connected || _api == null) {
        stage = ShareStage.error;
        failureMessage =
            'Companion backend is not running on port $port. Start it first.';
        addLog(failureMessage!, LogKind.error);
        notifyListeners();
        return;
      }
      addLog('Connected to ${_api!.origin}', LogKind.info);
    }

    stage = ShareStage.uploading;
    progress = 0.06;
    addLog(
      'Uploading ${formatBytes(bytes.length)} to ${_api!.origin}…',
      LogKind.transfer,
    );
    notifyListeners();

    try {
      final file = await _api!.uploadApk(
        fileName: fileName,
        bytes: bytes,
        onProgress: (value) {
          progress = 0.06 + value * 0.9;
          notifyListeners();
        },
      );
      staged = file;
      stage = ShareStage.ready;
      progress = 1;
      activeFileName = file.name;
      activeFileSize = file.size;
      addLog(
        '${file.name} staged — ${formatBytes(file.size)} ready to share',
        LogKind.success,
      );
      await refreshFiles();
      final url = pageUrl;
      if (url != null) addLog(url, LogKind.transfer);
    } on ShareApiException catch (error) {
      stage = ShareStage.error;
      failureMessage = error.message;
      addLog('Upload failed — ${error.message}', LogKind.error);
    } catch (error) {
      stage = ShareStage.error;
      failureMessage = '$error';
      addLog('Upload failed — $error', LogKind.error);
    }
    notifyListeners();
  }

  /// Phones downloading or done, newest first.
  List<DownloadEvent> get downloads => backend?.downloads ?? const [];
  int get activeDownloads => downloads.where((d) => d.isDownloading).length;
  int get finishedDownloads => downloads.where((d) => d.isDone).length;

  /// When true the QR code opens the list of all staged APKs.
  bool shareAll = false;

  void setShareAll(bool value) {
    shareAll = value;
    notifyListeners();
  }

  Timer? _poll;

  void _startPolling() {
    _poll ??= Timer.periodic(const Duration(seconds: 2), (_) {
      if (connected && !busy) refreshFiles();
    });
  }

  /// All APKs currently on the backend, newest first.
  List<HostedFile> get files => backend?.files ?? const [];

  /// Shows [file] in the QR card.
  void selectFile(HostedFile file) {
    if (busy) return;
    staged = file;
    stage = ShareStage.ready;
    progress = 1;
    activeFileName = file.name;
    activeFileSize = file.size;
    failureMessage = null;
    addLog('Sharing ${file.name}', LogKind.info);
  }

  /// Removes [file] from the backend and refreshes the list.
  Future<void> deleteFile(HostedFile file) async {
    final api = _api;
    if (api == null || busy) return;
    try {
      await api.deleteApk(file.name);
      addLog('${file.name} removed', LogKind.info);
      if (staged?.name == file.name) clearStaged();
      await refreshFiles();
    } catch (error) {
      addLog('Could not remove ${file.name} — $error', LogKind.error);
    }
  }

  /// Re-reads `/info` so the file list matches the disk.
  Future<void> refreshFiles() async {
    final api = _api;
    if (api == null) return;
    try {
      final info = await api.fetchInfo();
      backend = info;
      if (shareAll && info.files.length < 2) shareAll = false;
      notifyListeners();
    } catch (_) {}
  }

  /// Back to the idle drop zone (files stay on the server).
  void clearStaged() {
    stage = ShareStage.idle;
    progress = 0;
    staged = null;
    activeFileName = null;
    activeFileSize = null;
    failureMessage = null;
    notifyListeners();
  }

  void _fail(String message) {
    stage = ShareStage.error;
    failureMessage = message;
    addLog(message, LogKind.error);
    notifyListeners();
  }

  // --- log ----------------------------------------------------------------

  void addLog(String message, LogKind kind) {
    logs.add(LogEntry(DateTime.now(), message, kind));
    if (logs.length > 200) logs.removeAt(0);
    notifyListeners();
  }

  void clearLogs() {
    logs.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _api?.dispose();
    super.dispose();
  }
}
