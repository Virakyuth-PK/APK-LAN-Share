import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/share_controller.dart';
import 'panel_card.dart';

/// LAN IP + port entry with a reconnect action and live backend status.
class ConnectionPanel extends StatefulWidget {
  const ConnectionPanel({super.key, required this.controller});

  final ShareController controller;

  @override
  State<ConnectionPanel> createState() => _ConnectionPanelState();
}

class _ConnectionPanelState extends State<ConnectionPanel> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  final FocusNode _hostFocus = FocusNode();
  final FocusNode _portFocus = FocusNode();

  ShareController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: _controller.host);
    _portController = TextEditingController(text: '${_controller.port}');
    _controller.addListener(_syncFromController);
  }

  @override
  void dispose() {
    _controller.removeListener(_syncFromController);
    _hostController.dispose();
    _portController.dispose();
    _hostFocus.dispose();
    _portFocus.dispose();
    super.dispose();
  }

  /// Mirrors controller values into the fields — unless the user is typing.
  void _syncFromController() {
    if (!_hostFocus.hasFocus && _controller.host != _hostController.text) {
      _hostController.text = _controller.host;
    }
    final port = '${_controller.port}';
    if (!_portFocus.hasFocus && port != _portController.text) {
      _portController.text = port;
    }
  }

  Future<void> _apply() async {
    FocusScope.of(context).unfocus();
    await _controller.applyConnection(
      hostInput: _hostController.text,
      portInput: _portController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final text = Theme.of(context).textTheme;
        final connected = _controller.connected;
        final connecting = _controller.connecting;

        return PanelCard(
          title: 'Network',
          subtitle: 'Companion server address',
          icon: Icons.lan_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final fields = [
                    Expanded(
                      child: TextField(
                        controller: _hostController,
                        focusNode: _hostFocus,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'LAN IP address',
                          hintText: 'auto-detected',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 116,
                      child: TextField(
                        controller: _portController,
                        focusNode: _portFocus,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(5),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Port',
                          hintText: '8080',
                        ),
                      ),
                    ),
                  ];
                  final button = FilledButton.icon(
                    onPressed: connecting ? null : _apply,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(connecting ? 'Connecting…' : 'Reconnect'),
                  );

                  if (constraints.maxWidth < 620) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [...fields, const SizedBox(height: 12), button],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [...fields, const SizedBox(width: 12), button],
                  );
                },
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: connected
                    ? _statusRow(
                        context,
                        color: const Color(0xFF16A34A),
                        icon: Icons.bolt_rounded,
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: [
                            Text(
                              'Connected to ${_controller.backend?.baseUrl ?? ''}',
                              style: text.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_controller.backend != null)
                              Text(
                                '· storing in ${_controller.backend!.storageDir}',
                                style: text.bodySmall?.copyWith(
                                  color: scheme.outline,
                                ),
                              ),
                          ],
                        ),
                      )
                    : _statusRow(
                        context,
                        color: scheme.error,
                        icon: Icons.info_outline_rounded,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Backend not reachable on port '
                              '${_controller.port}. Run in a terminal:',
                              style: text.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _CommandChip(
                              command:
                                  'cd backend && dart run bin/server.dart --port ${_controller.port}',
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusRow(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required Widget child,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    );
  }
}

class _CommandChip extends StatelessWidget {
  const _CommandChip({required this.command});

  final String command;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              command,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                color: scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Copy command',
            icon: const Icon(Icons.copy_rounded, size: 16),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: command));
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(
                    const SnackBar(content: Text('Command copied')),
                  );
              }
            },
          ),
        ],
      ),
    );
  }
}
