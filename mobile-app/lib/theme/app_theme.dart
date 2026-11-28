import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // 60% Deep Charcoal Warm Black Canvas (Deep Charcoal Warm Black)
  static const Color canvas = Color(0xFF121110);
  static const Color canvasMuted = Color(0xFF191816);

  // 30% Crisp Ticket / Card Surfaces & Borders
  static const Color surface = Color(0xFF1A1917);
  static const Color surfaceAlt = Color(0xFF22201D);
  static const Color border = Color(0xFF2E2C29);
  static const Color borderStrong = Color(0xFF3E3B37);

  // Ink Hierarchy (WCAG AA >= 4.5:1 on dark charcoal)
  static const Color inkPrimary = Color(0xFFF4F2EC);
  static const Color inkSecondary = Color(0xFFA39E93);
  static const Color inkMuted = Color(0xFF6E6A63);

  // 10% Cinema Accent (Cinema Crimson #D93829 + Warm Amber Gold #D4A853)
  static const Color crimson = Color(0xFFD93829);
  static const Color crimsonPressed = Color(0xFFC83E2B);
  static const Color crimsonTint = Color(0x26D93829);
  static const Color amber = Color(0xFFD4A853);
  static const Color amberTint = Color(0x26D4A853);

  // Dark Screening Room (Auditorium & Trailer Player)
  static const Color darkStage = Color(0xFF0C0B0A);
  static const Color darkStageBorder = Color(0xFF2E2C29);

  // Motion & Radius Tokens
  static const Duration microDuration = Duration(milliseconds: 180);
  static const Curve microCurve = Curves.easeOutCubic;
  static const double radiusCard = 12.0;
  static const double radiusInner = 8.0;

  static TextStyle tabular(TextStyle base) {
    return base.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static TextStyle monoTabular({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w500,
    Color color = inkSecondary,
  }) {
    return TextStyle(
      fontFamily: 'monospace',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = const ColorScheme.dark(
      primary: crimson,
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: crimsonTint,
      onPrimaryContainer: crimson,
      secondary: inkPrimary,
      onSecondary: Color(0xFF121110),
      secondaryContainer: surfaceAlt,
      onSecondaryContainer: inkPrimary,
      tertiary: amber,
      onTertiary: Color(0xFF121110),
      surface: surface,
      onSurface: inkPrimary,
      surfaceContainerHighest: surfaceAlt,
      onSurfaceVariant: inkSecondary,
      outline: border,
      outlineVariant: borderStrong,
      error: Color(0xFFFCA5A5),
      onError: Color(0xFF121110),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: canvas,
      dividerColor: border,
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: inkPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: inkPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: inkPrimary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        indicatorColor: crimsonTint,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? crimson : inkSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? crimson : inkSecondary,
            size: 22,
          );
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: crimson,
          foregroundColor: Colors.white,
          disabledBackgroundColor: border,
          disabledForegroundColor: inkMuted,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusInner),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: inkPrimary,
          backgroundColor: surfaceAlt,
          side: const BorderSide(color: border, width: 1),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusInner),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: crimson,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInner),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInner),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInner),
          borderSide: const BorderSide(color: crimson, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInner),
          borderSide: const BorderSide(color: Color(0xFFFCA5A5), width: 1),
        ),
        labelStyle: const TextStyle(color: inkSecondary),
        hintStyle: const TextStyle(color: inkMuted),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }

  // Alias for backward compatibility if lightTheme was referenced
  static ThemeData get lightTheme => darkTheme;
}
