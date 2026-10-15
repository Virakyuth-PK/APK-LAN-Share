import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';

/// Details read from an APK's binary `AndroidManifest.xml`.
class ApkMeta {
  const ApkMeta({
    this.packageName,
    this.versionName,
    this.versionCode,
    this.label,
    this.minSdk,
    this.targetSdk,
    this.permissions = const [],
    this.iconPng,
    this.sha256,
  });

  final String? packageName;
  final String? versionName;
  final int? versionCode;
  final String? label;
  final int? minSdk;
  final int? targetSdk;
  final List<String> permissions;

  /// Largest launcher PNG found in the APK, if any (adaptive icons are XML
  /// and cannot be shown, so this may be null).
  final Uint8List? iconPng;
  final String? sha256;

  static const empty = ApkMeta();
}

/// Maps Android API level to a marketing version, e.g. 34 -> "Android 14".
String androidVersionName(int api) {
  const names = {
    21: '5.0',
    22: '5.1',
    23: '6.0',
    24: '7.0',
    25: '7.1',
    26: '8.0',
    27: '8.1',
    28: '9',
    29: '10',
    30: '11',
    31: '12',
    32: '12L',
    33: '13',
    34: '14',
    35: '15',
    36: '16',
  };
  final name = names[api];
  return name == null ? 'API $api' : 'Android $name (API $api)';
}

final _cache = <String, ApkMeta>{};

/// Reads (and caches by path + mtime + size) the metadata of [file].
/// Never throws: a corrupt APK yields [ApkMeta.empty] plus its hash.
Future<ApkMeta> readApkMeta(File file) async {
  final key =
      '${file.path}|${file.lastModifiedSync().microsecondsSinceEpoch}'
      '|${file.lengthSync()}';
  final cached = _cache[key];
  if (cached != null) return cached;

  String? hash;
  try {
    hash = (await sha256.bind(file.openRead()).first).toString();
  } catch (_) {}

  ApkMeta meta;
  try {
    meta = _parse(file, hash);
  } catch (_) {
    meta = ApkMeta(sha256: hash);
  }
  _cache
    ..removeWhere((k, _) => k.startsWith('${file.path}|'))
    ..[key] = meta;
  return meta;
}

ApkMeta _parse(File file, String? hash) {
  final input = InputFileStream(file.path);
  try {
    final archive = ZipDecoder().decodeStream(input);
    Uint8List? manifest;
    Uint8List? icon;
    var iconSize = 0;
    for (final entry in archive) {
      if (!entry.isFile) continue;
      if (entry.name == 'AndroidManifest.xml') {
        manifest = entry.readBytes();
      } else if (RegExp(r'^res/.*ic_launcher.*\.png$').hasMatch(entry.name) &&
          entry.size > iconSize) {
        icon = entry.readBytes();
        iconSize = entry.size;
      }
    }
    if (manifest == null) return ApkMeta(sha256: hash);
    final m = _parseManifest(manifest);
    return ApkMeta(
      packageName: m.package,
      versionName: m.versionName,
      versionCode: m.versionCode,
      label: m.label,
      minSdk: m.minSdk,
      targetSdk: m.targetSdk,
      permissions: m.permissions,
      iconPng: icon,
      sha256: hash,
    );
  } finally {
    input.close();
  }
}

class _Manifest {
  String? package;
  String? versionName;
  int? versionCode;
  String? label;
  int? minSdk;
  int? targetSdk;
  final permissions = <String>[];
}

// Android binary XML (AXML) constants.
const _chunkStringPool = 0x0001;
const _chunkStartElement = 0x0102;
const _typeString = 0x03;

_Manifest _parseManifest(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  var pos = data.getUint16(2, Endian.little); // file header size
  List<String> strings = const [];
  final out = _Manifest();

  String? str(int index) =>
      index >= 0 && index < strings.length ? strings[index] : null;

  while (pos + 8 <= bytes.length) {
    final type = data.getUint16(pos, Endian.little);
    final headerSize = data.getUint16(pos + 2, Endian.little);
    final size = data.getUint32(pos + 4, Endian.little);
    if (size < 8) break;

    if (type == _chunkStringPool) {
      strings = _readStringPool(data, bytes, pos);
    } else if (type == _chunkStartElement) {
      final body = pos + headerSize;
      final name = str(data.getInt32(body + 4, Endian.little));
      final attrStart = data.getUint16(body + 8, Endian.little);
      final attrSize = data.getUint16(body + 10, Endian.little);
      final attrCount = data.getUint16(body + 12, Endian.little);
      final attrs = <String, Object?>{};
      for (var i = 0; i < attrCount; i++) {
        final a = body + attrStart + i * attrSize;
        final attrName = str(data.getInt32(a + 4, Endian.little));
        if (attrName == null) continue;
        final raw = data.getInt32(a + 8, Endian.little);
        final valueType = data.getUint8(a + 15);
        final value = data.getUint32(a + 16, Endian.little);
        attrs[attrName] = valueType == _typeString
            ? str(raw)
            : (raw >= 0 ? str(raw) : value);
      }
      switch (name) {
        case 'manifest':
          out.package = attrs['package'] as String?;
          out.versionName = attrs['versionName']?.toString();
          final vc = attrs['versionCode'];
          out.versionCode = vc is int ? vc : int.tryParse('$vc');
        case 'uses-sdk':
          final min = attrs['minSdkVersion'];
          final target = attrs['targetSdkVersion'];
          out.minSdk = min is int ? min : null;
          out.targetSdk = target is int ? target : null;
        case 'uses-permission':
          final perm = attrs['name'];
          if (perm is String) out.permissions.add(perm);
        case 'application':
          final label = attrs['label'];
          if (label is String) out.label = label;
      }
    }
    pos += size;
  }
  return out;
}

List<String> _readStringPool(ByteData data, Uint8List bytes, int chunk) {
  final count = data.getUint32(chunk + 8, Endian.little);
  final flags = data.getUint32(chunk + 16, Endian.little);
  final stringsStart = data.getUint32(chunk + 20, Endian.little);
  final headerSize = data.getUint16(chunk + 2, Endian.little);
  final isUtf8 = flags & 0x100 != 0;
  final offsetsAt = chunk + headerSize;
  final result = <String>[];

  for (var i = 0; i < count; i++) {
    var p =
        chunk + stringsStart + data.getUint32(offsetsAt + i * 4, Endian.little);
    if (isUtf8) {
      // Two length prefixes: UTF-16 chars, then UTF-8 bytes (1-2 bytes each).
      if (bytes[p] & 0x80 != 0) p++;
      p++;
      var len = bytes[p++];
      if (len & 0x80 != 0) len = ((len & 0x7f) << 8) | bytes[p++];
      result.add(utf8.decode(bytes.sublist(p, p + len), allowMalformed: true));
    } else {
      var len = data.getUint16(p, Endian.little);
      p += 2;
      if (len & 0x8000 != 0) {
        len = ((len & 0x7fff) << 16) | data.getUint16(p, Endian.little);
        p += 2;
      }
      result.add(
        String.fromCharCodes([
          for (var j = 0; j < len; j++)
            data.getUint16(p + j * 2, Endian.little),
        ]),
      );
    }
  }
  return result;
}
