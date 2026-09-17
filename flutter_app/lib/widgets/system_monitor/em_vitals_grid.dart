import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../em_technical_grid.dart';

/// Vitals-mode background: technical grid + optional scan-line and radar sweep.
class EmVitalsGrid extends StatefulWidget {
  const EmVitalsGrid({
    super.key,
    required this.child,
    this.showScanLine = true,
    this.showRadarSweep = true,
  });

  final Widget child;
  final bool showScanLine;
  final bool showRadarSweep;

  @override
  State<EmVitalsGrid> createState() => _EmVitalsGridState();
}

class _EmVitalsGridState extends State<EmVitalsGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        EmTechnicalGrid(showBloom: true, child: const SizedBox.expand()),
        if (widget.showScanLine || widget.showRadarSweep)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _VitalsOverlayPainter(
                      scheme: scheme,
                      progress: _controller.value,
                      showScanLine: widget.showScanLine,
                      showRadarSweep: widget.showRadarSweep,
                    ),
                  );
                },
              ),
            ),
          ),
        Positioned.fill(child: widget.child),
      ],
    );
  }
}

class _VitalsOverlayPainter extends CustomPainter {
  _VitalsOverlayPainter({
    required this.scheme,
    required this.progress,
    required this.showScanLine,
    required this.showRadarSweep,
  });

  final ColorScheme scheme;
  final double progress;
  final bool showScanLine;
  final bool showRadarSweep;

  @override
  void paint(Canvas canvas, Size size) {
    if (showScanLine) {
      final y = size.height * progress;
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            scheme.primary.withValues(alpha: 0.04),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, y - 24, size.width, 48));
      canvas.drawRect(Rect.fromLTWH(0, y - 24, size.width, 48), paint);
    }

    if (showRadarSweep) {
      final center = Offset(size.width / 2, size.height * 0.35);
      final radius = math.min(size.width, size.height) * 0.55;
      final sweepAngle = math.pi / 6;
      final startAngle = progress * 2 * math.pi - math.pi / 2;
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle,
        true,
        Paint()
          ..shader = RadialGradient(
            colors: [
              scheme.tertiary.withValues(alpha: 0.06),
              Colors.transparent,
            ],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VitalsOverlayPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.scheme != scheme;
}
