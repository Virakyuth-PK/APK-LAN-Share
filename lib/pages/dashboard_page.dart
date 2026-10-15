import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

import '../models/share_models.dart';
import '../state/share_controller.dart';
import '../util/formatters.dart';
import '../util/web_drop.dart';
import '../widgets/activity_log.dart';
import '../widgets/connection_panel.dart';
import '../widgets/devices_card.dart';
import '../widgets/glass_card.dart';
import '../widgets/panel_card.dart';
import '../widgets/qr_share_card.dart';
import '../widgets/staged_files_card.dart';

/// Two-column dashboard that collapses to one column on narrow windows.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ShareController _controller = ShareController();

  /// Accepts a dropped file anywhere on the page, not just on the drop zone.
  late final WebDropListener _dropListener = WebDropListener(
    bounds: () => Rect.fromLTWH(
      0,
      0,
      web.window.innerWidth.toDouble(),
      web.window.innerHeight.toDouble(),
    ),
    onHover: _controller.setDragging,
    onDrop: (file) => _controller.dropFile(file.name, file.bytes),
  );

  @override
  void initState() {
    super.initState();
    _dropListener.attach();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.connect();
    });
  }

  @override
  void dispose() {
    _dropListener.detach();
    _controller.dispose();
    super.dispose();
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

  Future<void> _copyLink() async {
    final url = _controller.pageUrl;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    if (url == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Stage an APK first.')),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    messenger.showSnackBar(const SnackBar(content: Text('Link copied')));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            titleSpacing: 24,
            title: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.qr_code_rounded,
                    color: scheme.onPrimary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Text('APK LAN Share'),
              ],
            ),
            actions: [
              ConnectionBadge(
                connected: _controller.connected,
                connecting: _controller.connecting,
                host: _controller.host.isEmpty ? null : _controller.host,
                port: _controller.port,
              ),
              const SizedBox(width: 24),
            ],
          ),
          body: GlassBackdrop(
            child: Stack(
              children: [
                Positioned.fill(
                  child: SafeArea(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final wide = constraints.maxWidth >= 1000;
                            return SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(
                                wide ? 28 : 18,
                                64,
                                wide ? 28 : 18,
                                36,
                              ),
                              child: wide
                                  ? _wideLayout(text, scheme)
                                  : _narrowLayout(text, scheme),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                if (_controller.dragging) _dropOverlay(scheme, text),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _wideLayout(TextTheme text, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 10, child: _hero(text, scheme, 92)),
            const SizedBox(width: 26),
            Expanded(
              flex: 11,
              child: Column(
                children: [
                  QrShareCard(controller: _controller),
                  const SizedBox(height: 18),
                  DevicesCard(controller: _controller),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: StagedFilesCard(controller: _controller)),
            const SizedBox(width: 18),
            Expanded(child: ConnectionPanel(controller: _controller)),
          ],
        ),
        const SizedBox(height: 18),
        ActivityLog(controller: _controller),
      ],
    );
  }

  Widget _narrowLayout(TextTheme text, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _hero(text, scheme, 56),
        const SizedBox(height: 18),
        QrShareCard(controller: _controller),
        const SizedBox(height: 18),
        DevicesCard(controller: _controller),
        const SizedBox(height: 18),
        StagedFilesCard(controller: _controller),
        const SizedBox(height: 18),
        ConnectionPanel(controller: _controller),
        const SizedBox(height: 18),
        ActivityLog(controller: _controller),
      ],
    );
  }

  /// Poster headline, the two big buttons and the upload status.
  Widget _hero(TextTheme text, ColorScheme scheme, double size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SCAN.\nINSTALL.\nDONE.',
          style: text.displayLarge?.copyWith(
            fontSize: size,
            height: 0.88,
            fontWeight: FontWeight.w900,
            letterSpacing: -size * 0.06,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 22),
        _BigButton(
          label: '1 · Choose APK',
          icon: Icons.upload_rounded,
          primary: true,
          onTap: _controller.busy ? null : _pickFile,
        ),
        const SizedBox(height: 12),
        _BigButton(
          label: '2 · Copy link',
          icon: Icons.copy_rounded,
          onTap: _copyLink,
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            '…or drop a file anywhere on this page',
            style: text.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (_controller.busy || _controller.stage == ShareStage.error) ...[
          const SizedBox(height: 14),
          _UploadStatus(controller: _controller),
        ],
      ],
    );
  }

  /// Full-page hint shown while a file is dragged over the window.
  Widget _dropOverlay(ColorScheme scheme, TextTheme text) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.primary, width: 2),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.file_download_outlined,
                size: 56,
                color: scheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'Drop the APK anywhere to share it',
                style: text.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Large pill-shaped action; the primary one is filled blue glass.
class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = primary ? Colors.white : scheme.onSurface;

    return Opacity(
      opacity: onTap == null ? 0.55 : 1,
      child: GlassCard(
        padding: EdgeInsets.zero,
        radius: 20,
        tint: primary
            ? const LinearGradient(
                colors: [Color(0xCC1D4ED8), Color(0xDD0C2A52)],
              )
            : null,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: fg,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  Icon(icon, color: fg, size: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Upload progress / error shown under the buttons.
class _UploadStatus extends StatelessWidget {
  const _UploadStatus({required this.controller});

  final ShareController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final failed = controller.stage == ShareStage.error;
    final percent = (controller.progress * 100).clamp(0, 100).round();

    return GlassCard(
      padding: const EdgeInsets.all(16),
      radius: 18,
      child: failed
          ? Row(
              children: [
                Icon(Icons.error_outline_rounded, color: scheme.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    controller.failureMessage ?? 'Could not stage the file.',
                    style: text.bodyMedium?.copyWith(color: scheme.error),
                  ),
                ),
                TextButton(
                  onPressed: controller.clearStaged,
                  child: const Text('Dismiss'),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        controller.activeFileName ?? 'Uploading…',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      controller.stage == ShareStage.reading
                          ? 'Reading…'
                          : '$percent%',
                      style: text.titleSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Uploading ${formatBytes(controller.activeFileSize ?? 0)} — '
                  'keep this tab open.',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: LinearProgressIndicator(
                    value: controller.stage == ShareStage.reading
                        ? null
                        : controller.progress,
                    minHeight: 8,
                  ),
                ),
              ],
            ),
    );
  }
}
