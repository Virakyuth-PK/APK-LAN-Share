import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui';

import 'package:web/web.dart' as web;

/// A file dropped onto the page.
typedef DroppedFile = ({String name, Uint8List bytes});

/// Window-level HTML5 drag-and-drop listener.
///
/// Calls [onHover] with `true` while a file is dragged over [bounds] and
/// `false` otherwise. Calls [onDrop] when a file is released inside [bounds].
/// Drops outside [bounds] are ignored but still prevented, so the browser
/// never navigates to the dropped file.
class WebDropListener {
  WebDropListener({
    required this.bounds,
    required this.onHover,
    required this.onDrop,
  });

  /// Current target rectangle in logical (CSS) pixels.
  final Rect? Function() bounds;
  final void Function(bool hovering) onHover;
  final void Function(DroppedFile file) onDrop;

  late final JSFunction _over = ((web.DragEvent e) {
    if (!_hasFiles(e)) return;
    e.preventDefault();
    final inside = _inside(e);
    e.dataTransfer?.dropEffect = inside ? 'copy' : 'none';
    onHover(inside);
  }).toJS;

  late final JSFunction _leave = ((web.DragEvent e) {
    // relatedTarget is null when the pointer leaves the browser window.
    if (e.relatedTarget == null) onHover(false);
  }).toJS;

  late final JSFunction _drop = ((web.DragEvent e) {
    if (!_hasFiles(e)) return;
    e.preventDefault();
    onHover(false);
    if (!_inside(e)) return;
    final files = e.dataTransfer?.files;
    if (files == null || files.length == 0) return;
    final file = files.item(0)!;
    file.arrayBuffer().toDart.then((buffer) {
      onDrop((name: file.name, bytes: buffer.toDart.asUint8List()));
    });
  }).toJS;

  bool _hasFiles(web.DragEvent e) {
    final types = e.dataTransfer?.types;
    if (types == null) return false;
    for (var i = 0; i < types.length; i++) {
      if (types[i].toDart == 'Files') return true;
    }
    return false;
  }

  bool _inside(web.DragEvent e) =>
      bounds()?.contains(Offset(e.clientX.toDouble(), e.clientY.toDouble())) ??
      false;

  void attach() {
    web.window.addEventListener('dragenter', _over);
    web.window.addEventListener('dragover', _over);
    web.window.addEventListener('dragleave', _leave);
    web.window.addEventListener('drop', _drop);
  }

  void detach() {
    web.window.removeEventListener('dragenter', _over);
    web.window.removeEventListener('dragover', _over);
    web.window.removeEventListener('dragleave', _leave);
    web.window.removeEventListener('drop', _drop);
  }
}
