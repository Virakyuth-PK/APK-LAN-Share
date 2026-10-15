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
        final url = _controller.downloadUrl;
        final file = _controller.staged;

        return PanelCard(
          title: 'Share link',
          subtitle: url == null
              ? 'Appears once an APK is staged'
              : 'Scan to download — same Wi-Fi only',
          icon: Icons.qr_code_2_rounded,
          trailing: url == null
              ? null
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: Color(0xFF16A34A),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Live',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                ),
          child: url == null
              ? _placeholder(context)
              : _qrBody(context, url, file?.name),
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
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Icon(Icons.qr_code_2_rounded, size: 92, color: scheme.outline),
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

  Widget _qrBody(BuildContext context, String url, String? fileName) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    // Dark ink keeps scanners reliable in both light and dark themes.
    const ink = Color(0xFF1E1B4B);

    return Column(
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.12),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: QrImageView(
              data: url,
              size: 224,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.circle,
                color: ink,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.circle,
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
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _MetaChip(
              icon: Icons.android_outlined,
              label: fileName ?? 'APK',
              maxLabelWidth: 190,
            ),
            _MetaChip(icon: Icons.wifi_rounded, label: 'Same Wi-Fi network'),
            _MetaChip(icon: Icons.phone_iphone_rounded, label: 'Any device'),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Scan with any camera app. Devices must be on the same Wi-Fi; '
          'the link also works when typed manually.',
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.maxLabelWidth,
  });

  final IconData icon;
  final String label;
  final double? maxLabelWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Widget labelText = maxLabelWidth == null
        ? Text(label)
        : ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxLabelWidth!),
            child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          DefaultTextStyle(
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
            child: labelText,
          ),
        ],
      ),
    );
  }
}
