import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Primary CTA: 135° lithographic blue gradient (flutter_design-style), legible label.
class EmGradientButton extends StatelessWidget {
  const EmGradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.inProgress = false,
    this.padding = const EdgeInsets.symmetric(vertical: 16),
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  /// When true, shows a small throbber instead of [icon] (e.g. during connect).
  final bool inProgress;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = onPressed == null;
    // Match DESIGN.md / HTML: deep → bright along diagonal (container → primary in dark; rich blue in light).
    final List<Color> activeStops = scheme.brightness == Brightness.dark
        ? [
            scheme.primaryContainer,
            Color.lerp(scheme.primaryContainer, scheme.primary, 0.55)!,
            scheme.primary,
          ]
        : [
            Color.lerp(scheme.primary, Colors.black, 0.28)!,
            scheme.primary,
            Color.lerp(scheme.primary, scheme.primaryContainer, 0.42)!,
          ];
    final gradient = disabled
        ? LinearGradient(
            colors: [
              activeStops.first.withValues(alpha: 0.45),
              activeStops.last.withValues(alpha: 0.4),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: activeStops,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    final labelColor = scheme.onPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(8),
            boxShadow: disabled
                ? null
                : [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.22),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Padding(
            padding: padding,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (inProgress) ...[
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                ] else if (icon != null) ...[
                  Icon(icon, color: labelColor, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: labelColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
