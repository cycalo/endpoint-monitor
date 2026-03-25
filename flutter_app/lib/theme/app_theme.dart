import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'em_design_system.dart';

/// Cyber Slate — tokens from [flutter_design] HTML + DESIGN.md (Deep Slate + Cyber Blue).
const ColorScheme _orchestratorDarkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF98CBFF),
  onPrimary: Color(0xFF003354),
  primaryContainer: Color(0xFF0097EC),
  onPrimaryContainer: Color(0xFF002C4A),
  secondary: Color(0xFFB9C7DF),
  onSecondary: Color(0xFF233144),
  secondaryContainer: Color(0xFF3C4A5E),
  onSecondaryContainer: Color(0xFFABB9D1),
  tertiary: Color(0xFF2FD9F4),
  onTertiary: Color(0xFF00363E),
  tertiaryContainer: Color(0xFF009FB4),
  onTertiaryContainer: Color(0xFF002F36),
  error: Color(0xFFFFB4AB),
  onError: Color(0xFF690005),
  errorContainer: Color(0xFF93000A),
  onErrorContainer: Color(0xFFFFDAD6),
  surface: Color(0xFF0B1326),
  onSurface: Color(0xFFDAE2FD),
  surfaceContainerHighest: Color(0xFF2D3449),
  surfaceContainerHigh: Color(0xFF222A3D),
  surfaceContainer: Color(0xFF171F33),
  surfaceContainerLow: Color(0xFF131B2E),
  surfaceContainerLowest: Color(0xFF060E20),
  onSurfaceVariant: Color(0xFFC1C6D7),
  outline: Color(0xFF8B90A0),
  outlineVariant: Color(0xFF414754),
  shadow: Color(0x66000000),
  scrim: Color(0x99000000),
  inverseSurface: Color(0xFFDAE2FD),
  onInverseSurface: Color(0xFF283044),
  inversePrimary: Color(0xFF00629D),
  surfaceTint: Color(0xFF98CBFF),
);

const ColorScheme _orchestratorLightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF00629D),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFCFE5FF),
  onPrimaryContainer: Color(0xFF001D33),
  secondary: Color(0xFF475569),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFE2E8F0),
  onSecondaryContainer: Color(0xFF1E293B),
  tertiary: Color(0xFF007896),
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFCCEFFF),
  onTertiaryContainer: Color(0xFF001F25),
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
  inversePrimary: Color(0xFF98CBFF),
  surfaceTint: Color(0xFF00629D),
);

ThemeData buildEndpointMonitorDarkTheme() =>
    _buildEndpointMonitorTheme(_orchestratorDarkScheme);

ThemeData buildEndpointMonitorLightTheme() =>
    _buildEndpointMonitorTheme(_orchestratorLightScheme);

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

  final interBase = GoogleFonts.interTextTheme(base.textTheme);
  final manrope = GoogleFonts.manropeTextTheme(base.textTheme);

  final textTheme = interBase.copyWith(
    displayLarge: manrope.displayLarge?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      color: scheme.onSurface,
    ),
    displayMedium: manrope.displayMedium?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      color: scheme.onSurface,
    ),
    displaySmall: manrope.displaySmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: scheme.onSurface,
    ),
    headlineLarge: manrope.headlineLarge?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.35,
      color: scheme.onSurface,
    ),
    headlineMedium: manrope.headlineMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.25,
      color: scheme.onSurface,
    ),
    headlineSmall: manrope.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: scheme.onSurface,
    ),
    titleLarge: manrope.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      color: scheme.onSurface,
    ),
    titleMedium: interBase.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: scheme.onSurface,
    ),
    titleSmall: interBase.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: scheme.onSurface,
    ),
    bodyLarge: interBase.bodyLarge?.copyWith(color: scheme.onSurface),
    bodyMedium: interBase.bodyMedium?.copyWith(color: scheme.onSurface),
    bodySmall: interBase.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
    labelLarge: interBase.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      color: scheme.onSurfaceVariant,
    ),
    labelMedium: interBase.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
      color: scheme.onSurfaceVariant,
    ),
    labelSmall: interBase.labelSmall?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 1.0,
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
      titleTextStyle: GoogleFonts.manrope(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: scheme.onSurface,
      ),
      iconTheme: IconThemeData(color: scheme.primary, size: 24),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EmDesign.radiusLg),
        side: BorderSide(color: EmDesign.ghostLine(scheme), width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: _dialogSurface(scheme),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EmDesign.radiusLg),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      contentTextStyle: interBase.bodyMedium?.copyWith(color: scheme.onSurface),
      behavior: SnackBarBehavior.floating,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: scheme.surfaceContainerHighest,
      elevation: 0,
      indicatorColor: scheme.primary.withValues(alpha: 0.18),
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
          size: 22,
        );
      }),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurface,
      titleTextStyle: interBase.titleMedium,
      subtitleTextStyle:
          interBase.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EmDesign.radiusMd),
        borderSide: BorderSide(color: EmDesign.ghostLine(scheme), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EmDesign.radiusMd),
        borderSide: BorderSide(color: EmDesign.ghostLine(scheme), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EmDesign.radiusMd),
        borderSide: BorderSide(color: scheme.primary, width: 1),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(EmDesign.radiusMd),
        borderSide: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: scheme.outline.withValues(alpha: 0.45)),
      labelStyle: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
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
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(EmDesign.radiusSm),
          ),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        ),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      textStyle: interBase.bodyMedium?.copyWith(color: scheme.onSurface),
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
