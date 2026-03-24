import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cyber blue + slate — inspired by flutter_design gradients, no purple / no green primaries.
const ColorScheme _endpointMonitorDarkScheme = ColorScheme(
  brightness: Brightness.dark,
  // Brighter, more chromatic blues (still readable on dark slate).
  primary: Color(0xFF6BA3FF),
  onPrimary: Color(0xFF061225),
  primaryContainer: Color(0xFF1538A8),
  onPrimaryContainer: Color(0xFFE8F4FF),
  secondary: Color(0xFF94A3B8),
  onSecondary: Color(0xFF0F172A),
  secondaryContainer: Color(0xFF334155),
  onSecondaryContainer: Color(0xFFE2E8F0),
  // Accent: sky cyan (status / highlights) — stays in the blue family, not mint green.
  tertiary: Color(0xFF22D3FF),
  onTertiary: Color(0xFF001018),
  tertiaryContainer: Color(0xFF005F99),
  onTertiaryContainer: Color(0xFFD6F3FF),
  error: Color(0xFFFFB4AB),
  onError: Color(0xFF690005),
  errorContainer: Color(0xFF93000A),
  onErrorContainer: Color(0xFFFFDAD6),
  surface: Color(0xFF0F1218),
  onSurface: Color(0xFFE2E8F0),
  surfaceContainerHighest: Color(0xFF2A3140),
  surfaceContainerHigh: Color(0xFF222936),
  surfaceContainer: Color(0xFF1A2030),
  surfaceContainerLow: Color(0xFF151A26),
  surfaceContainerLowest: Color(0xFF0C0F16),
  onSurfaceVariant: Color(0xFF94A3B8),
  outline: Color(0xFF64748B),
  outlineVariant: Color(0xFF3D4A5C),
  shadow: Color(0x66000000),
  scrim: Color(0x99000000),
  inverseSurface: Color(0xFFE2E8F0),
  onInverseSurface: Color(0xFF1E293B),
  inversePrimary: Color(0xFF1D5CFF),
  surfaceTint: Color(0xFF4B8FFF),
);

const ColorScheme _endpointMonitorLightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF1D56F0),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFC8E0FF),
  onPrimaryContainer: Color(0xFF142E7A),
  secondary: Color(0xFF475569),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFE2E8F0),
  onSecondaryContainer: Color(0xFF1E293B),
  tertiary: Color(0xFF0077C8),
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFCCEAFF),
  onTertiaryContainer: Color(0xFF003A5C),
  error: Color(0xFFBA1A1A),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFFDAD6),
  onErrorContainer: Color(0xFF410002),
  surface: Color(0xFFF8FAFC),
  onSurface: Color(0xFF0F172A),
  surfaceContainerHighest: Color(0xFFE2E8F0),
  surfaceContainerHigh: Color(0xFFE8EEF5),
  surfaceContainer: Color(0xFFF1F5F9),
  surfaceContainerLow: Color(0xFFF8FAFC),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  onSurfaceVariant: Color(0xFF475569),
  outline: Color(0xFF94A3B8),
  outlineVariant: Color(0xFFCBD5E1),
  shadow: Color(0x26000000),
  scrim: Color(0x66000000),
  inverseSurface: Color(0xFF1E293B),
  onInverseSurface: Color(0xFFF1F5F9),
  inversePrimary: Color(0xFF6BA3FF),
  surfaceTint: Color(0xFF1D56F0),
);

ThemeData buildEndpointMonitorDarkTheme() =>
    _buildEndpointMonitorTheme(_endpointMonitorDarkScheme);

ThemeData buildEndpointMonitorLightTheme() =>
    _buildEndpointMonitorTheme(_endpointMonitorLightScheme);

/// Dialog / overlay surface (slightly distinct from cards).
Color _dialogSurface(ColorScheme scheme) {
  return Color.alphaBlend(
    scheme.surfaceContainerHigh
        .withValues(alpha: scheme.brightness == Brightness.dark ? 0.92 : 0.98),
    scheme.surface,
  );
}

ThemeData _buildEndpointMonitorTheme(ColorScheme scheme) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: scheme.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    dividerColor: Colors.transparent,
    splashColor: scheme.primary.withValues(alpha: 0.08),
    highlightColor: scheme.primary.withValues(alpha: 0.06),
  );

  final inter = GoogleFonts.interTextTheme(base.textTheme);
  final space = GoogleFonts.spaceGroteskTextTheme(base.textTheme);

  final textTheme = inter.copyWith(
    displayLarge: space.displayLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: scheme.onSurface,
    ),
    displayMedium: space.displayMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: scheme.onSurface,
    ),
    displaySmall: space.displaySmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: scheme.onSurface,
    ),
    headlineLarge: space.headlineLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.25,
      color: scheme.onSurface,
    ),
    headlineMedium: space.headlineMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: scheme.onSurface,
    ),
    headlineSmall: space.headlineSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: scheme.onSurface,
    ),
    titleLarge: space.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      color: scheme.onSurface,
    ),
    titleMedium: inter.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: scheme.onSurface,
    ),
    titleSmall: inter.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: scheme.onSurfaceVariant,
    ),
    bodyLarge: inter.bodyLarge?.copyWith(color: scheme.onSurface),
    bodyMedium: inter.bodyMedium?.copyWith(color: scheme.onSurface),
    bodySmall: inter.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
    labelLarge: inter.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
      color: scheme.onSurfaceVariant,
    ),
    labelMedium: inter.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
      color: scheme.onSurfaceVariant,
    ),
    labelSmall: inter.labelSmall?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.9,
      color: scheme.outline,
    ),
  );

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.primary,
      titleTextStyle: GoogleFonts.spaceGrotesk(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
        color: scheme.primary,
      ),
      iconTheme: IconThemeData(color: scheme.primary, size: 24),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      margin: EdgeInsets.zero,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: _dialogSurface(scheme),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      contentTextStyle: inter.bodyMedium?.copyWith(color: scheme.onSurface),
      behavior: SnackBarBehavior.floating,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: scheme.surface,
      elevation: 0,
      shadowColor: scheme.primary.withValues(alpha: 0.06),
      indicatorColor: scheme.primaryContainer,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: selected ? scheme.onPrimaryContainer : scheme.outlineVariant,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? scheme.onPrimaryContainer : scheme.outlineVariant,
          size: 22,
        );
      }),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurface,
      titleTextStyle: inter.titleMedium,
      subtitleTextStyle:
          inter.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: scheme.primary, width: 1),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: scheme.outline.withValues(alpha: 0.5)),
      labelStyle: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: scheme.onSurfaceVariant,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.surfaceContainerHigh;
          }
          return Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          return scheme.outline;
        }),
        side: WidgetStateProperty.all(BorderSide.none),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      textStyle: inter.bodyMedium?.copyWith(color: scheme.onSurface),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
    ),
    iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
  );
}
