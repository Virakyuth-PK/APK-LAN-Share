import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../state/share_controller.dart';
import 'panel_card.dart';

/// Centered QR code with the plain-text URL underneath.
class QrShareCard extends StatefulWidget {
  const QrShareCard({super.key, required this.controller});

  final ShareController controller;

  @override
  State<QrShareCard> createState() => _QrShareCardState();
}

class _QrShareCardState extends State<QrShareCard> {
  bool _copied = false;

  ShareController get _controller => widget.controller;

  Future<void> _copy(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final url = _controller.pageUrl;

        return PanelCard(
          title: 'Share link',
          subtitle: url == null
              ? 'Appears once an APK is staged'
              : 'Scan with a phone on the same Wi-Fi',
          icon: Icons.qr_code_2_rounded,
          trailing: url == null
              ? null
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: Color(0xFF16A34A)),
                    SizedBox(width: 6),
                    Text(
                      'Live',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
          child: url == null ? _placeholder(context) : _qrBody(context, url),
        );
      },
    );
  }

  // ------------------------------------------------------------- states

  Widget _placeholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(Icons.qr_code_2_rounded, size: 72, color: scheme.outline),
          const SizedBox(height: 14),
          Text(
            'QR code appears here',
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Stage an APK to generate a download link\nfor every device on this network.',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: scheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _qrBody(BuildContext context, String url) {
    final scheme = Theme.of(context).colorScheme;
    // Dark ink keeps scanners reliable in both light and dark themes.
    const ink = Color(0xFF18181B);

    return Column(
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: QrImageView(
              data: url,
              size: 224,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: ink,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: ink,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  url,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: _copied ? 'Copied' : 'Copy link',
                child: IconButton(
                  onPressed: () => _copy(url),
                  visualDensity: VisualDensity.compact,
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: Icon(
                      _copied ? Icons.check_rounded : Icons.copy_rounded,
                      key: ValueKey(_copied),
                      size: 18,
                      color: _copied ? const Color(0xFF16A34A) : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_controller.files.length > 1) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              'Share all ${_controller.files.length} APKs',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('QR opens a list with a button per file'),
            value: _controller.shareAll,
            onChanged: _controller.setShareAll,
          ),
        ],
      ],
    );
  }
}
