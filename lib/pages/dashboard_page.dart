import 'package:flutter/material.dart';

import '../state/share_controller.dart';
import '../widgets/activity_log.dart';
import '../widgets/connection_panel.dart';
import '../widgets/drop_zone.dart';
import '../widgets/panel_card.dart';
import '../widgets/qr_share_card.dart';

/// Two-column dashboard that collapses to one column on narrow windows.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ShareController _controller = ShareController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.connect();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 24,
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [scheme.primary, scheme.tertiary],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.qr_code_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
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
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 1000;

                    final dropZone = PanelCard(
                      title: 'Stage an APK',
                      subtitle: 'Drag a file in, or click to browse',
                      icon: Icons.upload_file_outlined,
                      trailing: _controller.busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                      child: DropZone(controller: _controller),
                    );
                    final qrCard = QrShareCard(controller: _controller);
                    final connection = ConnectionPanel(controller: _controller);

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _hero(text, scheme),
                          const SizedBox(height: 22),
                          if (wide) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 12, child: dropZone),
                                const SizedBox(width: 20),
                                Expanded(flex: 9, child: qrCard),
                              ],
                            ),
                            const SizedBox(height: 20),
                            connection,
                          ] else ...[
                            dropZone,
                            const SizedBox(height: 20),
                            qrCard,
                            const SizedBox(height: 20),
                            connection,
                          ],
                          const SizedBox(height: 20),
                          ActivityLog(controller: _controller),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _hero(TextTheme text, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Share an APK with anyone on this Wi-Fi',
          style: text.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Text(
            'Stage a file on this computer, then scan the QR code from any '
            'phone or tablet connected to the same network — no cloud, no '
            'cables, no accounts.',
            style: text.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
