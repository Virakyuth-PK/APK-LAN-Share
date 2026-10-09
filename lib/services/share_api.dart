import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

import '../models/share_models.dart';

/// A transport-level failure raised by [ShareApi].
class ShareApiException implements Exception {
  const ShareApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Typed client for the companion backend.
///
/// The health check uses `package:http`; the upload uses `XMLHttpRequest`
/// directly so the dashboard can report *real* byte-level progress (the
/// browser's `fetch` API does not expose upload progress without streams).
class ShareApi {
  ShareApi(this.origin);

  /// Backend origin, e.g. `http://127.0.0.1:8080`.
  final String origin;

  final http.Client _client = http.Client();

  /// `GET /info` — verifies the backend is alive and returns its LAN identity.
  Future<BackendInfo> fetchInfo({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final response = await _client
        .get(Uri.parse('$origin/info'))
        .timeout(timeout, onTimeout: () {
      throw const ShareApiException('Backend did not respond in time.');
    });

    if (response.statusCode != 200) {
      throw ShareApiException(
        'Backend answered HTTP ${response.statusCode} on /info.',
        statusCode: response.statusCode,
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const ShareApiException(
        'That port answered, but it is not the APK LAN Share backend.',
      );
    }
    if (decoded is! Map<String, dynamic> || decoded['ok'] != true) {
      throw const ShareApiException(
        'That port answered, but it is not the APK LAN Share backend.',
      );
    }
    return BackendInfo.fromJson(decoded);
  }

  /// `POST /upload?name=<file>.apk` with the raw file body.
  ///
  /// [onProgress] receives `0.0`–`1.0` as the browser flushes bytes.
  Future<HostedFile> uploadApk({
    required String fileName,
    required Uint8List bytes,
    void Function(double progress)? onProgress,
  }) {
    final completer = Completer<HostedFile>();
    final uri =
        Uri.parse('$origin/upload').replace(queryParameters: {'name': fileName});
    final xhr = web.XMLHttpRequest();

    void fail(String message) {
      if (!completer.isCompleted) {
        completer.completeError(ShareApiException(message));
      }
    }

    xhr.open('POST', uri.toString());
    xhr.setRequestHeader('Content-Type', 'application/octet-stream');
    xhr.setRequestHeader('Accept', 'application/json');

    xhr.upload.onprogress = ((web.ProgressEvent event) {
      if (onProgress != null &&
          event.lengthComputable &&
          event.total > 0) {
        final value = (event.loaded / event.total).clamp(0.0, 1.0);
        onProgress(value);
      }
    }.toJS);

    xhr.onload = ((web.Event _) {
      final status = xhr.status;
      final body = xhr.responseText;
      if (status < 200 || status >= 300) {
        var message = 'Backend answered HTTP $status.';
        try {
          final decoded = jsonDecode(body);
          if (decoded is Map<String, dynamic> &&
              decoded['error'] is String) {
            message = decoded['error'] as String;
          }
        } catch (_) {
          // Non-JSON error body — keep the status message.
        }
        fail(message);
        return;
      }

      try {
        final decoded = jsonDecode(body);
        if (decoded is! Map<String, dynamic> || decoded['ok'] != true) {
          fail('Backend rejected the upload.');
          return;
        }
        final file = decoded['file'];
        if (file is! Map<String, dynamic>) {
          fail('Backend response was missing file details.');
          return;
        }
        if (!completer.isCompleted) {
          completer.complete(HostedFile.fromJson(file));
        }
      } catch (_) {
        fail('Could not read the backend response.');
      }
    }.toJS);

    xhr.onerror = ((web.Event _) {
      fail('Network error while uploading to $origin — is the companion '
          'backend still running?');
    }.toJS);
    xhr.ontimeout = ((web.Event _) => fail('Upload timed out.')).toJS;
    xhr.onabort = ((web.Event _) => fail('Upload was aborted.')).toJS;

    xhr.send(bytes.toJS);
    return completer.future;
  }

  void dispose() => _client.close();
}
