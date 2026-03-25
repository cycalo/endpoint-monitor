import 'dart:ui';

import 'package:flutter/material.dart';

/// Subtle technical grid + optional blue bloom (Connect screen).
class EmTechnicalGrid extends StatelessWidget {
  const EmTechnicalGrid({
    super.key,
    required this.child,
    this.showBloom = true,
  });

  final Widget child;
  final bool showBloom;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _TechnicalGridPainter(scheme.outlineVariant)),
        if (showBloom)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                  child: Container(
                    width: 480,
                    height: 480,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          scheme.primaryContainer.withValues(alpha: 0.18),
                          scheme.primary.withValues(alpha: 0.09),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        // Fill the stack so scroll views get a finite max height (avoids blank body).
        Positioned.fill(child: child),
      ],
    );
  }
}

class _TechnicalGridPainter extends CustomPainter {
  _TechnicalGridPainter(this.lineColor);

  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = lineColor.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    const step = 40.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant _TechnicalGridPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor;
}
