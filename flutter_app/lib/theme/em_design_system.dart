import 'package:flutter/material.dart';

/// Tokens aligned with [flutter_design/cyber_slate_console/DESIGN.md] — tonal layering, ghost edges.
abstract final class EmDesign {
  /// Spacing rhythm (DESIGN.md §6 — generous section gaps).
  static const double spaceXs = 6;
  static const double spaceSm = 10;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 28;
  static const double space2xl = 32;

  static const double radiusSm = 6;
  static const double radiusMd = 8;
  static const double radiusLg = 12;
  static const double radiusXl = 16;

  /// Screen content padding above bottom nav safe area.
  static const double scrollBottomInset = 96;

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
