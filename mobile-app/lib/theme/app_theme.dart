import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // 60% Warm Paper Canvas & Tinted Surfaces
  static const Color canvas = Color(0xFFFAF9F5);
  static const Color canvasMuted = Color(0xFFF3F1EA);

  // 30% Crisp Ticket / Card Surfaces & Borders
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2DFD7);
  static const Color borderStrong = Color(0xFFD0CCC1);

  // Ink Hierarchy (WCAG AA >= 4.5:1 on warm paper)
  static const Color inkPrimary = Color(0xFF191918);
  static const Color inkSecondary = Color(0xFF62605B);
  static const Color inkMuted = Color(0xFF8C8982);

  // 10% Cinema Accent (Classic Crimson + Warm Amber Gold)
  static const Color crimson = Color(0xFFC83E2B);
  static const Color crimsonPressed = Color(0xFFA93221);
  static const Color crimsonTint = Color(0xFFFDF2F0);
  static const Color amber = Color(0xFFD4A853);
  static const Color amberTint = Color(0xFFFBF6EA);

  // Dark Screening Room (Trailer Player)
  static const Color darkStage = Color(0xFF191918);
  static const Color darkStageBorder = Color(0xFF2C2B29);

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

  static ThemeData get lightTheme {
    final colorScheme = const ColorScheme.light(
      primary: crimson,
      onPrimary: Colors.white,
      primaryContainer: crimsonTint,
      onPrimaryContainer: crimsonPressed,
      secondary: inkPrimary,
      onSecondary: Colors.white,
      secondaryContainer: canvasMuted,
      onSecondaryContainer: inkPrimary,
      tertiary: amber,
      onTertiary: inkPrimary,
      surface: surface,
      onSurface: inkPrimary,
      surfaceContainerHighest: canvasMuted,
      onSurfaceVariant: inkSecondary,
      outline: border,
      outlineVariant: border,
      error: crimson,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: canvas,
      dividerColor: border,
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: canvas,
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
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: crimson,
          foregroundColor: Colors.white,
          disabledBackgroundColor: border,
          disabledForegroundColor: inkMuted,
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusInner),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: inkPrimary,
          backgroundColor: surface,
          side: const BorderSide(color: border, width: 1),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusInner),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: crimson,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusInner),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        labelStyle: const TextStyle(color: inkSecondary, fontSize: 14),
        hintStyle: const TextStyle(color: inkMuted, fontSize: 14),
        prefixIconColor: inkSecondary,
        suffixIconColor: inkSecondary,
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
          borderSide: const BorderSide(color: crimson, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: canvasMuted,
        selectedColor: crimsonTint,
        disabledColor: canvasMuted,
        labelStyle: const TextStyle(color: inkPrimary, fontSize: 12, fontWeight: FontWeight.w500),
        secondaryLabelStyle: const TextStyle(color: crimson, fontSize: 12, fontWeight: FontWeight.w600),
        side: const BorderSide(color: border, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusInner),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return crimsonTint;
            return surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return crimson;
            return inkSecondary;
          }),
          side: WidgetStateProperty.all(const BorderSide(color: border, width: 1)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusInner)),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: inkPrimary,
        contentTextStyle: const TextStyle(color: canvas, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusInner)),
      ),
    );
  }
}
