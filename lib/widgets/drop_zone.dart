import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/share_models.dart';
import '../state/share_controller.dart';
import '../util/formatters.dart';
import 'dashed_border.dart';

/// Interactive staging area: drag-and-drop or browse for an `.apk`, then
/// morphs into a progress bar and finally a success state.
class DropZone extends StatefulWidget {
  const DropZone({super.key, required this.controller});

  final ShareController controller;

  @override
  State<DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<DropZone> {
  bool _dragging = false;

  ShareController get _controller => widget.controller;

  Future<void> _onUploadClick() async {
    await _pickFile();
  }

  Future<void> _pickFile() async {
    if (_controller.busy) return;
    final picked = await FilePicker.pickFiles(
      dialogTitle: 'Select an APK to share',
      type: FileType.custom,
      allowedExtensions: const ['apk'],
    );
    if (picked.isEmpty) return;
    final file = picked.first;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    await _controller.stageFile(fileName: file.name, bytes: bytes);
  }

  Future<void> _onDrop(DropDoneDetails details) async {
    setState(() => _dragging = false);
    if (_controller.busy) return;

    DropItem? apk;
    for (final item in details.files) {
      if (item.name.toLowerCase().endsWith('.apk')) {
        apk = item;
        break;
      }
    }
    if (apk == null) {
      _controller.addLog(
        'Ignored drop — only .apk files can be shared.',
        LogKind.error,
      );
      return;
    }

    final bytes = await apk.readAsBytes();
    if (!mounted) return;
    await _controller.stageFile(fileName: apk.name, bytes: bytes);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final stage = _controller.stage;
        final busy = _controller.busy;

        final Color borderColor;
        if (_dragging) {
          borderColor = scheme.primary;
        } else if (stage == ShareStage.ready) {
          borderColor = const Color(0xFF16A34A);
        } else if (stage == ShareStage.error) {
          borderColor = scheme.error;
        } else {
          borderColor = scheme.outline;
        }

        return DropTarget(
          enable: !busy,
          onDragEntered: (_) => setState(() => _dragging = true),
          onDragExited: (_) => setState(() => _dragging = false),
          onDragDone: _onDrop,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: _dragging
                  ? scheme.primaryContainer.withValues(alpha: 0.45)
                  : scheme.surface,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(26),
                onTap: busy ? null : _onUploadClick,
                child: DashedRRectBorder(
                  color: borderColor,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 0.04),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: _buildContent(context, stage),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, ShareStage stage) {
    if (_dragging) return _dragHint(context);
    return switch (stage) {
      ShareStage.idle => _idle(context),
      ShareStage.reading || ShareStage.uploading => _uploading(context),
      ShareStage.ready => _ready(context),
      ShareStage.error => _error(context),
    };
  }

  Widget _dragHint(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      key: const ValueKey('drag'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.file_download_outlined, size: 54, color: scheme.primary),
        const SizedBox(height: 14),
        Text(
          'Release to stage this APK',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
        ),
      ],
    );
  }

  Widget _idle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      key: const ValueKey('idle'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.upload_file_outlined,
            size: 30,
            color: scheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Drop your APK here',
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'or click to browse your computer',
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _onUploadClick,
          icon: const Icon(Icons.upload_file_outlined, size: 18),
          label: const Text('Upload APK'),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: const [
            _HintChip(icon: Icons.touch_app_outlined, label: 'Drag & drop'),
            _HintChip(icon: Icons.wifi_outlined, label: 'Same Wi-Fi only'),
            _HintChip(icon: Icons.security_outlined, label: 'Stays local'),
          ],
        ),
      ],
    );
  }

  Widget _uploading(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final reading = _controller.stage == ShareStage.reading;
    final percent = (_controller.progress * 100).clamp(0, 100).round();

    return Column(
      key: const ValueKey('uploading'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.android_outlined,
                color: scheme.onPrimaryContainer,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _controller.activeFileName ?? 'Uploading…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    reading
                        ? 'Reading ${formatBytes(_controller.activeFileSize ?? 0)} from disk…'
                        : 'Uploading ${formatBytes(_controller.activeFileSize ?? 0)} to the companion server…',
                    style: text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (!reading)
              Text(
                '$percent%',
                style: text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: reading ? null : _controller.progress,
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.bolt_outlined, size: 15, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Keep this tab open until staging completes.',
                style: text.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _ready(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final file = _controller.staged;

    return Column(
      key: const ValueKey('ready'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: Color(0xFFDCFCE7),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 34,
            color: Color(0xFF16A34A),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          file?.name ?? 'APK staged',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${formatBytes(file?.size ?? 0)} · ready to share',
          style: text.bodyMedium?.copyWith(
            color: const Color(0xFF16A34A),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: _controller.clearStaged,
          icon: const Icon(Icons.add_rounded, size: 19),
          label: const Text('Stage another APK'),
        ),
      ],
    );
  }

  Widget _error(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      key: const ValueKey('error'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.error_outline_rounded,
            size: 32,
            color: scheme.onErrorContainer,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Could not stage the file',
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 7),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Text(
            _controller.failureMessage ?? 'Unknown error.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: scheme.error),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _controller.clearStaged,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Try again'),
        ),
      ],
    );
  }
}

class _HintChip extends StatelessWidget {
  const _HintChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

