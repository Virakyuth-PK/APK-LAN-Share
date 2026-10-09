/// Formats a byte count for humans: `0 B`, `2 KB`, `1.5 MB`, `2.3 GB`.
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var index = 0;
  while (value >= 1024 && index < units.length - 1) {
    value /= 1024;
    index++;
  }
  if (index == 0) return '$bytes B';
  var text = value.toStringAsFixed(1);
  if (text.endsWith('.0')) text = text.substring(0, text.length - 2);
  return '$text ${units[index]}';
}

/// `14:03:09` — used for activity-log timestamps.
String formatClock(DateTime time) => [
      time.hour.toString().padLeft(2, '0'),
      time.minute.toString().padLeft(2, '0'),
      time.second.toString().padLeft(2, '0'),
    ].join(':');
