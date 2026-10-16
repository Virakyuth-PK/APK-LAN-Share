import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/share_models.dart';
import '../util/formatters.dart';
import '../widgets/glass_card.dart';
import '../widgets/panel_card.dart';
import 'host_controller.dart';

/// Single-screen host UI: pick APKs, share the hotspot, watch downloads.
class HostPage extends StatefulWidget {
  const HostPage({super.key});

  @override
  State<HostPage> createState() => _HostPageState();
}

class _HostPageState extends State<HostPage> {
  final HostController _host = HostController();

  @override
  void initState() {
    super.initState();
    _host.start();
  }

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GlassBackdrop(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: _host,
            builder: (context, _) => Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    _Header(host: _host),
                    const SizedBox(height: 16),
                    if (_host.error != null) ...[
                      _ErrorBanner(message: _host.error!),
                      const SizedBox(height: 16),
                    ],
                    _ApkCard(host: _host),
                    if (_host.running &&
                        _host.pageUrl != null &&
                        _host.files.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _QrCard(host: _host),
                    ],
                    const SizedBox(height: 16),
                    _HotspotCard(host: _host),
                    if (_host.running) ...[
                      const SizedBox(height: 16),
                      _DevicesCard(host: _host),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.host});

  final HostController host;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.asset('assets/brand/logo.png', width: 48, height: 48),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'APK LAN Share',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                host.running
                    ? 'Sharing on port ${host.port}'
                    : host.starting
                    ? 'Starting…'
                    : 'Server stopped',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: host.running
                      ? const Color(0xFF16A34A)
                      : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: host.running,
          onChanged: host.starting ? null : (_) => host.toggle(),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: scheme.error)),
          ),
        ],
      ),
    );
  }
}

class _ApkCard extends StatelessWidget {
  const _ApkCard({required this.host});

  final HostController host;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = host.importProgress;

    return PanelCard(
      title: 'APK files',
      subtitle: host.files.isEmpty
          ? 'Add an APK to share'
          : '${host.files.length} ready to download',
      icon: Icons.android_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: host.running && progress == null
                ? host.pickAndAdd
                : null,
            icon: const Icon(Icons.upload_file_rounded),
            label: Text(
              progress == null
                  ? 'Choose APK'
                  : 'Adding ${host.importName ?? ''}…',
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: progress, minHeight: 6),
            ),
          ],
          for (final file in host.files) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        formatBytes(file.size),
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove',
                  onPressed: () => host.deleteFile(file),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HotspotCard extends StatelessWidget {
  const _HotspotCard({required this.host});

  final HostController host;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final hotspot = host.hotspot;

    Widget step(String number, String label) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              number,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: text.bodyMedium)),
        ],
      ),
    );

    return PanelCard(
      title: 'Connect other devices',
      subtitle: hotspot != null
          ? 'Hotspot on · ${hotspot.ip}'
          : 'Hotspot off — Wi-Fi works too',
      icon: Icons.wifi_tethering_rounded,
      trailing: Icon(
        Icons.circle,
        size: 10,
        color: hotspot != null ? const Color(0xFF16A34A) : scheme.outline,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          step('1', 'Turn on this phone\'s hotspot.'),
          step('2', 'Join that hotspot from the other device.'),
          step('3', 'Scan the QR code or open the link below.'),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final opened = await host.openHotspotSettings();
              if (!opened) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Open Settings → Hotspot & tethering.'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.settings_rounded),
            label: const Text('Open hotspot settings'),
          ),
          if (host.addresses.length > 1) ...[
            const SizedBox(height: 14),
            Text('Share on', style: text.labelMedium),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final address in host.addresses)
                  ChoiceChip(
                    label: Text('${address.ip} · ${address.name}'),
                    selected: address.ip == host.selectedIp,
                    onSelected: (_) => host.selectIp(address.ip),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  const _QrCard({required this.host});

  final HostController host;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = host.pageUrl!;

    return PanelCard(
      title: 'Share link',
      subtitle: host.files.isEmpty
          ? 'Add an APK first'
          : 'Scan from a device on this network',
      icon: Icons.qr_code_2_rounded,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: QrImageView(
              data: url,
              size: 200,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF1E3A8A),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF1E3A8A),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: SelectableText(
                  url,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy link',
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(ClipboardData(text: url));
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Link copied')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DevicesCard extends StatelessWidget {
  const _DevicesCard({required this.host});

  final HostController host;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = host.downloads;

    return PanelCard(
      title: 'Devices',
      subtitle: items.isEmpty
          ? 'Waiting for the first download'
          : '${host.activeDownloads} downloading · '
                '${items.where((d) => d.isDone).length} done',
      icon: Icons.devices_rounded,
      child: items.isEmpty
          ? Text(
              'Devices that download an APK show up here with live progress.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            )
          : Column(
              children: [
                for (var i = 0; i < items.length && i < 6; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _DeviceRow(event: items[i]),
                ],
              ],
            ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.event});

  final DownloadEvent event;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = event.isDone
        ? 'Done'
        : event.isAborted
        ? 'Stopped'
        : '${(event.progress * 100).round()}%';
    final color = event.isDone
        ? const Color(0xFF16A34A)
        : event.isAborted
        ? scheme.error
        : scheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${event.device} · ${event.ip}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              status,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '${event.file} · ${formatBytes(event.total)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: event.progress,
            minHeight: 6,
            color: color,
          ),
        ),
      ],
    );
  }
}
