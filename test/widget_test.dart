import 'package:apk_lan_share/models/share_models.dart';
import 'package:apk_lan_share/util/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatBytes', () {
    test('handles zero and small values', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(512), '512 B');
    });

    test('scales to KB/MB/GB without trailing .0', () {
      expect(formatBytes(1024), '1 KB');
      expect(formatBytes(1536), '1.5 KB');
      expect(formatBytes(2052), '2 KB');
      expect(formatBytes(4 * 1024 * 1024), '4 MB');
      expect(formatBytes((2.5 * 1024 * 1024 * 1024).round()), '2.5 GB');
    });
  });

  group('HostedFile', () {
    test('parses backend payload', () {
      final file = HostedFile.fromJson(const {
        'name': 'demo.apk',
        'size': 2052,
        'uploadedAt': '2026-10-08T14:29:16.589027',
        'downloadPath': '/download/demo.apk',
      });
      expect(file.name, 'demo.apk');
      expect(file.size, 2052);
      expect(
        file.urlOn('http://192.168.0.21:8080'),
        'http://192.168.0.21:8080/download/demo.apk',
      );
    });

    test('tolerates missing fields', () {
      final file = HostedFile.fromJson(const {});
      expect(file.size, 0);
      expect(file.downloadPath, '');
    });
  });

  group('BackendInfo', () {
    test('parses /info payload including files', () {
      final info = BackendInfo.fromJson(const {
        'ok': true,
        'lanIp': '192.168.0.21',
        'port': 8099,
        'baseUrl': 'http://192.168.0.21:8099',
        'storageDir': '/tmp/public',
        'servesUi': false,
        'files': [
          {
            'name': 'demo.apk',
            'size': 2052,
            'uploadedAt': '2026-10-08T14:29:16.589027',
            'downloadPath': '/download/demo.apk',
          }
        ],
      });
      expect(info.lanIp, '192.168.0.21');
      expect(info.port, 8099);
      expect(info.files.single.name, 'demo.apk');
    });
  });
}
