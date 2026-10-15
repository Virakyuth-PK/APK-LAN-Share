/// Lifecycle of staging a single APK.
enum ShareStage {
  /// Nothing staged yet.
  idle,

  /// Bytes are being read from the picked/dropped file.
  reading,

  /// Bytes are streaming to the companion backend.
  uploading,

  /// The backend confirmed the file — QR code is live.
  ready,

  /// Something went wrong; see [failureMessage].
  error,
}

/// Severity of an activity-log entry.
enum LogKind { info, transfer, success, error }

/// A single line in the dashboard's activity log.
class LogEntry {
  const LogEntry(this.time, this.message, this.kind);

  final DateTime time;
  final String message;
  final LogKind kind;
}

/// An APK that has been staged on the companion backend.
class HostedFile {
  const HostedFile({
    required this.name,
    required this.size,
    required this.uploadedAt,
    required this.downloadPath,
  });

  factory HostedFile.fromJson(Map<String, dynamic> json) => HostedFile(
    name: json['name'] as String? ?? '',
    size: (json['size'] as num?)?.toInt() ?? 0,
    uploadedAt:
        DateTime.tryParse(json['uploadedAt'] as String? ?? '') ??
        DateTime.now(),
    downloadPath: json['downloadPath'] as String? ?? '',
  );

  final String name;
  final int size;
  final DateTime uploadedAt;

  /// Server-relative path, e.g. `/download/app.apk`.
  final String downloadPath;

  /// Absolute download URL for a given origin (`http://192.168.1.7:8080`).
  String urlOn(String origin) => '$origin$downloadPath';
}

/// Payload returned by `GET /info`.
class BackendInfo {
  const BackendInfo({
    required this.lanIp,
    required this.port,
    required this.baseUrl,
    required this.storageDir,
    required this.servesUi,
    required this.files,
  });

  factory BackendInfo.fromJson(Map<String, dynamic> json) => BackendInfo(
    lanIp: json['lanIp'] as String? ?? '127.0.0.1',
    port: (json['port'] as num?)?.toInt() ?? 8080,
    baseUrl: json['baseUrl'] as String? ?? '',
    storageDir: json['storageDir'] as String? ?? '',
    servesUi: json['servesUi'] as bool? ?? false,
    files: (json['files'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(HostedFile.fromJson)
        .toList(),
  );

  final String lanIp;
  final int port;
  final String baseUrl;
  final String storageDir;
  final bool servesUi;
  final List<HostedFile> files;
}
