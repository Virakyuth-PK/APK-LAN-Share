import 'package:flutter/material.dart';

import '../state/share_controller.dart';
import '../util/formatters.dart';
import 'panel_card.dart';

/// Every APK on the backend: pick which one the QR code points to, or remove it.
class StagedFilesCard extends StatelessWidget {
  const StagedFilesCard({super.key, required this.controller});

  final ShareController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final files = controller.files;
        final selected = controller.staged?.name;

        return PanelCard(
          title: 'Staged APKs',
          subtitle: files.isEmpty
              ? 'Nothing on the server yet'
              : '${files.length} on the server — pick one to share',
          icon: Icons.folder_open_rounded,
          trailing: IconButton(
            tooltip: 'Refresh list',
            onPressed: controller.connected ? controller.refreshFiles : null,
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
          child: files.isEmpty
              ? Text(
                  'Staged files appear here and survive a dashboard reload.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                )
              : Column(
                  children: [
                    for (final file in files)
                      ListTile(
                        key: ValueKey(file.name),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        selected: file.name == selected,
                        selectedColor: scheme.primary,
                        leading: const Icon(Icons.android_outlined),
                        title: Text(
                          file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(formatBytes(file.size)),
                        onTap: controller.busy
                            ? null
                            : () => controller.selectFile(file),
                        trailing: IconButton(
                          tooltip: 'Remove from server',
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: controller.busy
                              ? null
                              : () => controller.deleteFile(file),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}
