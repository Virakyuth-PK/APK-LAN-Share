import 'dart:ui';

import 'package:flutter/material.dart';

/// Frosted-glass surface: blurred backdrop, translucent fill, bright edge.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 22,
    this.tint,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Optional solid tint mixed into the glass (e.g. the primary button).
  final Gradient? tint;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final borderRadius = BorderRadius.circular(radius);

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient:
                tint ??
                LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: dark
                      ? const [Color(0x1FFFFFFF), Color(0x0AFFFFFF)]
                      : const [Color(0xB8FFFFFF), Color(0x66FFFFFF)],
                ),
            border: Border.all(
              color: dark ? const Color(0x26FFFFFF) : const Color(0xD0FFFFFF),
            ),
            boxShadow: [
              BoxShadow(
                color: dark ? const Color(0x66000000) : const Color(0x222563EB),
                blurRadius: 40,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Soft light-blue page backdrop with colour glows behind the glass.
class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    Widget glow(Alignment at, double radius, Color color) => Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: at,
            radius: radius,
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF0B1730), Color(0xFF0A1228)]
              : const [Color(0xFFEAF4FF), Color(0xFFCFE5FF), Color(0xFFA9CDFF)],
          stops: dark ? null : const [0, 0.55, 1],
        ),
      ),
      child: Stack(
        children: [
          if (!dark) glow(const Alignment(-1, -1), 0.9, Colors.white),
          glow(
            const Alignment(1, 1),
            0.9,
            dark ? const Color(0x551D4ED8) : const Color(0xFF8EC5FF),
          ),
          glow(
            const Alignment(0.6, -1),
            0.7,
            dark ? const Color(0x447C3AED) : const Color(0x88C4B5FD),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}
