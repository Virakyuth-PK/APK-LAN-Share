import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A rounded-rectangle border drawn as dashes (Flutter has no built-in
/// dashed stroke, and this avoids an extra dependency).
class DashedRRectBorder extends StatelessWidget {
  const DashedRRectBorder({
    super.key,
    required this.child,
    this.color,
    this.strokeWidth = 2,
    this.dashLength = 10,
    this.dashGap = 8,
    this.radius = 26,
    this.padding = const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
  });

  final Widget child;
  final Color? color;
  final double strokeWidth;
  final double dashLength;
  final double dashGap;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(
        color: color ?? Theme.of(context).colorScheme.outline,
        strokeWidth: strokeWidth,
        dashLength: dashLength,
        dashGap: dashGap,
        radius: radius,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.dashGap,
    required this.radius,
  });

  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double dashGap;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      var drawSegment = true;
      while (distance < metric.length) {
        final length = math.max(
          0.5,
          drawSegment ? dashLength : dashGap,
        );
        final end = math.min(distance + length, metric.length);
        if (drawSegment) {
          canvas.drawPath(metric.extractPath(distance, end), paint);
        }
        distance = end;
        drawSegment = !drawSegment;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dashLength != dashLength ||
      oldDelegate.dashGap != dashGap ||
      oldDelegate.radius != radius;
}
