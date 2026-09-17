import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Builds a normalized polyline path from [values] (0–100 or arbitrary range).
Path emVitalSparklinePath({
  required List<double> values,
  required Size size,
  double minY = 0,
  double? maxY,
  double padding = 2,
}) {
  final path = Path();
  if (values.isEmpty || size.width <= 0 || size.height <= 0) return path;

  final effectiveMax = maxY ??
      values.reduce(math.max).clamp(1.0, double.infinity).toDouble();
  final range =
      (effectiveMax - minY).clamp(0.001, double.infinity).toDouble();
  final w = size.width - padding * 2;
  final h = size.height - padding * 2;

  for (var i = 0; i < values.length; i++) {
    final x = padding + (values.length == 1 ? w / 2 : (i / (values.length - 1)) * w);
    final normalized = ((values[i] - minY) / range).clamp(0.0, 1.0);
    final y = padding + h - normalized * h;
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  return path;
}

/// Builds a dual-series sparkline for network up/down (bytes/sec).
Path emNetworkSparklinePath({
  required List<double> sentValues,
  required List<double> recvValues,
  required Size size,
  double padding = 2,
}) {
  final combined = [...sentValues, ...recvValues];
  if (combined.isEmpty) return Path();
  final maxY = combined.reduce(math.max).clamp(1.0, double.infinity).toDouble();
  // Use sent as primary line; recv could be overlaid separately.
  return emVitalSparklinePath(
    values: sentValues,
    size: size,
    maxY: maxY,
    padding: padding,
  );
}

/// Real-data sparkline painter (not decorative).
class EmVitalSparklinePainter extends CustomPainter {
  EmVitalSparklinePainter({
    required this.values,
    required this.lineColor,
    this.fillColor,
    this.minY = 0,
    this.maxY,
    this.strokeWidth = 1.5,
  });

  final List<double> values;
  final Color lineColor;
  final Color? fillColor;
  final double minY;
  final double? maxY;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final linePath = emVitalSparklinePath(
      values: values,
      size: size,
      minY: minY,
      maxY: maxY,
    );

    if (fillColor != null && values.length > 1) {
      final fillPath = Path.from(linePath)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..color = fillColor!
          ..style = PaintingStyle.fill,
      );
    }

    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant EmVitalSparklinePainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.maxY != maxY;
}

/// Scrollable mini sparkline widget.
class EmVitalSparkline extends StatelessWidget {
  const EmVitalSparkline({
    super.key,
    required this.values,
    required this.color,
    this.height = 36,
    this.maxY,
    this.showFill = true,
  });

  final List<double> values;
  final Color color;
  final double height;
  final double? maxY;
  final bool showFill;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: EmVitalSparklinePainter(
          values: values,
          lineColor: color,
          fillColor: showFill ? color.withValues(alpha: 0.12) : null,
          maxY: maxY,
        ),
      ),
    );
  }
}
