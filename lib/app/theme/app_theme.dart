import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const dianaPink = Color(0xFFE799B0);
  static const deepRose = Color(0xFF8A3E59);
  static const ink = Color(0xFF451E2C);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colors =
        ColorScheme.fromSeed(
          seedColor: dianaPink,
          brightness: brightness,
        ).copyWith(
          primary: dark ? dianaPink : deepRose,
          onPrimary: dark ? ink : Colors.white,
          primaryContainer: dark
              ? const Color(0xFF502A39)
              : const Color(0xFFFBE5ED),
          onPrimaryContainer: dark ? const Color(0xFFFFD9E5) : ink,
          surface: dark ? const Color(0xFF191619) : const Color(0xFFFFFBFC),
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      navigationBarTheme: const NavigationBarThemeData(height: 68),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
