/// One phone downloading one APK.
class DownloadRecord {
  DownloadRecord({
    required this.id,
    required this.file,
    required this.ip,
    required this.device,
    required this.total,
  }) : startedAt = DateTime.now();

  final int id;
  final String file;
  final String ip;
  final String device;
  final int total;
  final DateTime startedAt;

  int sent = 0;

  /// `downloading`, `done` or `aborted`.
  String status = 'downloading';
  DateTime? finishedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'file': file,
    'ip': ip,
    'device': device,
    'total': total,
    'sent': sent > total ? total : sent,
    'status': status,
    'startedAt': startedAt.toIso8601String(),
    'finishedAt': finishedAt?.toIso8601String(),
  };
}

/// Keeps the most recent downloads in memory so the dashboard and the phone
/// page can show who is downloading what, and who has finished.
class DownloadTracker {
  DownloadTracker({this.maxRecords = 60});

  final int maxRecords;
  final List<DownloadRecord> _records = [];
  int _nextId = 1;

  /// Starts (or resumes) a download. A ranged request that starts after byte 0
  /// continues the previous unfinished record for the same phone and file.
  DownloadRecord begin({
    required String file,
    required String ip,
    required String device,
    required int total,
    int offset = 0,
  }) {
    if (offset > 0) {
      for (final record in _records.reversed) {
        if (record.file == file &&
            record.ip == ip &&
            record.status != 'done' &&
            DateTime.now().difference(record.startedAt).inMinutes < 30) {
          record.status = 'downloading';
          record.finishedAt = null;
          record.sent = offset;
          return record;
        }
      }
    }
    final record = DownloadRecord(
      id: _nextId++,
      file: file,
      ip: ip,
      device: device,
      total: total,
    )..sent = offset;
    _records.add(record);
    if (_records.length > maxRecords) _records.removeAt(0);
    return record;
  }

  /// Wraps [source] so every chunk updates [record]; marks it done or aborted.
  Stream<List<int>> track(
    Stream<List<int>> source,
    DownloadRecord record,
  ) async* {
    try {
      await for (final chunk in source) {
        record.sent += chunk.length;
        yield chunk;
      }
      if (record.sent >= record.total) record.status = 'done';
    } finally {
      if (record.status != 'done') record.status = 'aborted';
      record.finishedAt = DateTime.now();
    }
  }

  /// Newest first. [ip] limits the list to one phone.
  List<Map<String, Object?>> toJson({String? ip, int limit = 30}) => _records
      .reversed
      .where((r) => ip == null || r.ip == ip)
      .take(limit)
      .map((r) => r.toJson())
      .toList();
}

/// Turns a User-Agent into a short device name, e.g. "Pixel 8".
String deviceLabel(String? userAgent) {
  final ua = userAgent ?? '';
  final android = RegExp(r'Android [\d.]+; ([^;)]+?)(?: Build|;|\))')
      .firstMatch(ua);
  if (android != null) {
    final model = android.group(1)!.trim();
    if (model.isNotEmpty && model != 'K') return model;
  }
  if (ua.contains('Android')) return 'Android device';
  if (ua.contains('iPhone')) return 'iPhone';
  if (ua.contains('iPad')) return 'iPad';
  if (ua.contains('Macintosh')) return 'Mac browser';
  if (ua.contains('Windows')) return 'Windows browser';
  if (ua.contains('Linux')) return 'Linux browser';
  return 'Unknown device';
}
