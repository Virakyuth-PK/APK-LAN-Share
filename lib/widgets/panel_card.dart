import 'package:flutter/material.dart';

import 'glass_card.dart';

/// Consistent card shell: icon + title on top, optional trailing widget.
class PanelCard extends StatelessWidget {
  const PanelCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
    this.subtitle,
    this.contentPadding = const EdgeInsets.all(20),
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2);

    return GlassCard(
      padding: contentPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: titleStyle),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Compact online / connecting / offline pill for the app bar.
class ConnectionBadge extends StatelessWidget {
  const ConnectionBadge({
    super.key,
    required this.connected,
    required this.connecting,
    this.host,
    this.port,
  });

  final bool connected;
  final bool connecting;
  final String? host;
  final int? port;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final Color color;
    final String label;
    if (connecting) {
      color = scheme.tertiary;
      label = 'Connecting…';
    } else if (connected) {
      color = const Color(0xFF16A34A);
      label = host == null ? 'Online' : 'Online · $host:$port';
    } else {
      color = scheme.error;
      label = 'Offline';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (connecting)
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(strokeWidth: 1.8, color: color),
          )
        else
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
