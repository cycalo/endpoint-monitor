import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/em_design_system.dart';
import '../../utils/em_vital_band.dart';
import 'em_vital_sparkline.dart';

/// Central radial health ring with live CPU waveform.
class EmVitalsHero extends StatefulWidget {
  const EmVitalsHero({
    super.key,
    required this.healthScore,
    required this.worstBand,
    required this.cpuHistory,
    this.compact = false,
  });

  final double healthScore;
  final EmVitalBand worstBand;
  final List<double> cpuHistory;
  final bool compact;

  @override
  State<EmVitalsHero> createState() => _EmVitalsHeroState();
}

class _EmVitalsHeroState extends State<EmVitalsHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: widget.worstBand == EmVitalBand.critical ? 2000 : 3000,
      ),
    );
    if (widget.worstBand == EmVitalBand.critical) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant EmVitalsHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.worstBand != widget.worstBand) {
      _pulseController.duration = Duration(
        milliseconds: widget.worstBand == EmVitalBand.critical ? 2000 : 3000,
      );
      if (widget.worstBand == EmVitalBand.critical) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.value = 1;
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = emVitalBandColor(scheme, widget.worstBand);
    final size = widget.compact ? 180.0 : 220.0;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final glowAlpha = widget.worstBand == EmVitalBand.critical
            ? 0.88 + _pulseController.value * 0.12
            : 1.0;
        return SizedBox(
          height: size + 24,
          child: Center(
            child: SizedBox(
              width: size,
              height: size,
              child: CustomPaint(
                painter: _HeroRingPainter(
                  scheme: scheme,
                  accent: accent.withValues(alpha: glowAlpha),
                  healthScore: widget.healthScore,
                  cpuHistory: widget.cpuHistory,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.healthScore.round().toString(),
                        style: GoogleFonts.manrope(
                          fontSize: widget.compact ? 42 : 52,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ENDPOINT HEALTH',
                        style: EmDesign.labelCaps(context, scheme),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeroRingPainter extends CustomPainter {
  _HeroRingPainter({
    required this.scheme,
    required this.accent,
    required this.healthScore,
    required this.cpuHistory,
  });

  final ColorScheme scheme;
  final Color accent;
  final double healthScore;
  final List<double> cpuHistory;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = scheme.surfaceContainerHighest.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10,
    );

    final sweep = (healthScore / 100) * 2 * math.pi;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = accent.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    if (cpuHistory.isNotEmpty) {
      final innerW = radius * 1.4;
      final innerH = radius * 0.5;
      final innerRect = Rect.fromCenter(
        center: center.translate(0, radius * 0.15),
        width: innerW,
        height: innerH,
      );
      final wavePath = emVitalSparklinePath(
        values: cpuHistory,
        size: Size(innerRect.width, innerRect.height),
        maxY: 100,
      );
      canvas.save();
      canvas.translate(innerRect.left, innerRect.top);
      canvas.drawPath(
        wavePath,
        Paint()
          ..color = accent.withValues(alpha: 0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _HeroRingPainter oldDelegate) =>
      oldDelegate.healthScore != healthScore ||
      oldDelegate.accent != accent ||
      oldDelegate.cpuHistory != cpuHistory;
}
