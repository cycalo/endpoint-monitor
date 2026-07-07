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

  /// Control screen left-accent colors derived from the active [ColorScheme].
  static Color controlSession(ColorScheme scheme) => scheme.tertiary;

  static Color controlPowerWarn(ColorScheme scheme) =>
      Color.lerp(scheme.error, scheme.tertiary, 0.42)!;

  static Color controlPowerCritical(ColorScheme scheme) => scheme.error;

  static Color controlDisplay(ColorScheme scheme) => scheme.primary;

  static Color controlCancel(ColorScheme scheme) => scheme.onSurfaceVariant;

  static Color controlAudio(ColorScheme scheme) =>
      Color.lerp(scheme.primary, scheme.tertiary, 0.35)!;

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

  /// Layered ambient shadows for the dashboard connection hero — soft glow, not harsh drop-shadow.
  static List<BoxShadow> heroElevationShadows(
    ColorScheme scheme, {
    Color? accentGlow,
  }) {
    final dark = scheme.brightness == Brightness.dark;
    final shadows = <BoxShadow>[
      BoxShadow(
        color: scheme.onSurface.withValues(alpha: dark ? 0.045 : 0.03),
        blurRadius: 52,
        spreadRadius: -6,
      ),
      BoxShadow(
        color: scheme.onSurface.withValues(alpha: dark ? 0.085 : 0.05),
        blurRadius: 22,
        offset: const Offset(0, 10),
      ),
      BoxShadow(
        color: scheme.shadow.withValues(alpha: dark ? 0.12 : 0.065),
        blurRadius: 8,
        offset: const Offset(0, 3),
      ),
    ];
    if (accentGlow != null) {
      shadows.add(
        BoxShadow(
          color: accentGlow.withValues(alpha: dark ? 0.14 : 0.09),
          blurRadius: 32,
          spreadRadius: -8,
          offset: const Offset(0, 6),
        ),
      );
    }
    return shadows;
  }

  /// Tonal gradient shell for the elevated hero card (DESIGN.md §2 / §4).
  static BoxDecoration heroCardDecoration(
    ColorScheme scheme, {
    double radius = radiusLg,
  }) {
    final dark = scheme.brightness == Brightness.dark;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? [
                scheme.surfaceContainerHigh,
                scheme.surfaceContainer,
                Color.lerp(
                  scheme.surfaceContainer,
                  scheme.surfaceContainerLow,
                  0.35,
                )!,
              ]
            : [
                scheme.surfaceContainerHigh,
                scheme.surfaceContainer,
                scheme.surfaceContainerLow,
              ],
        stops: const [0.0, 0.45, 1.0],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: ghostBorder(scheme),
    );
  }

  /// Recessed icon well inside the connection hero.
  static BoxDecoration heroIconWellDecoration(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: dark
            ? [
                scheme.surfaceContainerLow,
                Color.lerp(
                  scheme.surfaceContainerLow,
                  scheme.surfaceContainerLowest,
                  0.5,
                )!,
              ]
            : [
                scheme.surfaceContainerLow,
                scheme.surfaceContainerLowest,
              ],
      ),
      borderRadius: BorderRadius.circular(radiusMd),
      border: ghostBorder(scheme),
      boxShadow: [
        BoxShadow(
          color: scheme.shadow.withValues(alpha: dark ? 0.16 : 0.07),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
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
