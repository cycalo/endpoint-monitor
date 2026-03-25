import 'package:flutter/material.dart';

/// Tokens aligned with [flutter_design/cyber_slate_console/DESIGN.md] — tonal layering, ghost edges.
abstract final class EmDesign {
  static const double radiusSm = 6;
  static const double radiusMd = 8;
  static const double radiusLg = 12;
  static const double radiusXl = 16;

  /// "Ghost border" — outline_variant @ ~15% (DESIGN.md §2 / §4).
  static Color ghostLine(ColorScheme scheme) =>
      scheme.outlineVariant.withValues(alpha: 0.15);

  /// Explicit 1px sides — avoids hairline `width: 0` assertions with [BorderRadius].
  static Border ghostBorder(ColorScheme scheme) => Border.all(
        color: ghostLine(scheme),
        width: 1,
      );

  static BoxDecoration cardShell(
    ColorScheme scheme, {
    Color? color,
    double radius = radiusLg,
    bool ghostEdge = true,
  }) {
    return BoxDecoration(
      color: color ?? scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(radius),
      border: ghostEdge ? ghostBorder(scheme) : null,
    );
  }

  /// Editorial label: uppercase, wide tracking (HTML mocks).
  static TextStyle labelCaps(BuildContext context, ColorScheme scheme) {
    final base = Theme.of(context).textTheme.labelSmall ??
        Theme.of(context).textTheme.bodySmall ??
        const TextStyle();
    return base.copyWith(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 2,
      color: scheme.onSurfaceVariant,
    );
  }
}
