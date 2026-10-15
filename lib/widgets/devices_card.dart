import 'package:flutter/material.dart';

import '../models/share_models.dart';
import '../state/share_controller.dart';
import '../util/formatters.dart';
import 'panel_card.dart';

/// Live list of phones: who is downloading (progress bar) and who is done.
class DevicesCard extends StatelessWidget {
  const DevicesCard({super.key, required this.controller});

  final ShareController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final items = controller.downloads;

        return PanelCard(
          title: 'Devices',
          subtitle: items.isEmpty
              ? 'Waiting for the first scan'
              : '${controller.activeDownloads} downloading · '
                    '${controller.finishedDownloads} done',
          icon: Icons.devices_rounded,
          child: items.isEmpty
              ? Text(
                  'Phones that open the link or download an APK show up here '
                  'with live progress.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                )
              : Column(
                  children: [
                    for (var i = 0; i < items.length && i < 8; i++) ...[
                      if (i > 0)
                        Divider(color: scheme.outlineVariant, height: 1),
                      _DeviceRow(event: items[i]),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.event});

  final DownloadEvent event;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final Color color;
    final String chip;
    if (event.isDownloading) {
      color = scheme.primary;
      chip = '${(event.progress * 100).round()}%';
    } else if (event.isDone) {
      color = const Color(0xFF15803D);
      chip = '✓ Done';
    } else {
      color = scheme.error;
      chip = 'Stopped';
    }

    final sub = event.isDownloading
        ? '${event.ip} · ${formatBytes(event.sent)} / ${formatBytes(event.total)}'
        : '${event.file} · ${formatBytes(event.total)} · '
              '${formatClock(event.finishedAt ?? event.startedAt)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Icon(
              Icons.smartphone_rounded,
              size: 19,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.device,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (event.isDownloading) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: LinearProgressIndicator(
                      value: event.progress,
                      minHeight: 6,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              chip,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
