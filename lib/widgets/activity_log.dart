import 'package:flutter/material.dart';

import '../models/share_models.dart';
import '../state/share_controller.dart';
import '../util/formatters.dart';
import 'panel_card.dart';

/// Scrolling log of connection + staging events.
class ActivityLog extends StatefulWidget {
  const ActivityLog({super.key, required this.controller});

  final ShareController controller;

  @override
  State<ActivityLog> createState() => _ActivityLogState();
}

class _ActivityLogState extends State<ActivityLog> {
  final ScrollController _scrollController = ScrollController();

  ShareController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToEnd());
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // Follow the tail only when the user is already near the bottom.
    if (position.pixels >= position.maxScrollExtent - 60) {
      _jumpToEnd();
    }
  }

  void _jumpToEnd() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final entries = _controller.logs;

        return PanelCard(
          title: 'Activity',
          subtitle: entries.isEmpty
              ? 'Nothing yet'
              : '${entries.length} event${entries.length == 1 ? '' : 's'}',
          icon: Icons.receipt_long_outlined,
          trailing: entries.isEmpty
              ? null
              : TextButton(
                  onPressed: _controller.clearLogs,
                  child: const Text('Clear'),
                ),
          child: entries.isEmpty
              ? _empty(context)
              : SizedBox(
                  height: 200,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 2),
                    itemCount: entries.length,
                    itemBuilder: (context, index) =>
                        _row(context, entries[index]),
                  ),
                ),
        );
      },
    );
  }

  Widget _empty(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            'Staging and connection events appear here.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, LogEntry entry) {
    final scheme = Theme.of(context).colorScheme;

    final Color color = switch (entry.kind) {
      LogKind.info => scheme.onSurfaceVariant,
      LogKind.transfer => scheme.primary,
      LogKind.success => const Color(0xFF16A34A),
      LogKind.error => scheme.error,
    };
    final bool mono =
        entry.kind == LogKind.transfer || entry.kind == LogKind.error;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 7),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 11),
          SizedBox(
            width: 60,
            child: Text(
              formatClock(entry.time),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                color: scheme.outline,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.message,
              style: TextStyle(
                fontSize: mono ? 12.5 : 13.5,
                height: 1.45,
                fontFamily: mono ? 'monospace' : null,
                fontWeight: FontWeight.w400,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
