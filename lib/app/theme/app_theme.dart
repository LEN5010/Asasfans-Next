import 'package:flutter/material.dart';

import 'app_tokens.dart';

abstract final class AppTheme {
  static const dianaPink = Color(0xFFE799B0);
  static const deepRose = Color(0xFF8A3E59);
  static const ink = Color(0xFF451E2C);

  static final light = _build(Brightness.light);
  static final dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final page = dark ? AppTokens.pageDark : AppTokens.pageLight;
    final content = dark ? AppTokens.contentDark : AppTokens.contentLight;
    final control = dark ? AppTokens.controlDark : AppTokens.controlLight;
    final colors =
        ColorScheme.fromSeed(
          seedColor: dianaPink,
          brightness: brightness,
        ).copyWith(
          primary: dark ? dianaPink : deepRose,
          onPrimary: dark ? ink : Colors.white,
          primaryContainer: dark
              ? AppTokens.selectedDark
              : AppTokens.selectedLight,
          onPrimaryContainer: dark ? dianaPink : deepRose,
          secondaryContainer: control,
          onSecondaryContainer: dark ? AppTokens.textDark : AppTokens.textLight,
          surface: page,
          surfaceDim: dark ? const Color(0xFF101012) : const Color(0xFFEAE9ED),
          surfaceBright: dark ? const Color(0xFF353339) : Colors.white,
          surfaceContainerLowest: dark ? const Color(0xFF121214) : Colors.white,
          surfaceContainerLow: content,
          surfaceContainer: content,
          surfaceContainerHigh: control,
          surfaceContainerHighest: dark
              ? const Color(0xFF34323A)
              : const Color(0xFFE8E6EC),
          onSurface: dark ? AppTokens.textDark : AppTokens.textLight,
          onSurfaceVariant: dark
              ? AppTokens.secondaryDark
              : AppTokens.secondaryLight,
          outline: dark ? const Color(0xFF8E8997) : const Color(0xFF88828F),
          outlineVariant: dark ? AppTokens.dividerDark : AppTokens.dividerLight,
          surfaceTint: Colors.transparent,
          inverseSurface: dark ? AppTokens.textDark : AppTokens.textLight,
          onInverseSurface: dark ? AppTokens.textLight : AppTokens.textDark,
        );
    final base = ThemeData(useMaterial3: true, colorScheme: colors);
    final text = base.textTheme.copyWith(
      titleLarge: base.textTheme.titleLarge!.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: base.textTheme.titleMedium!.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: base.textTheme.titleSmall!.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.textTheme.bodyLarge!.copyWith(fontSize: 15, height: 1.45),
      bodyMedium: base.textTheme.bodyMedium!.copyWith(
        fontSize: 14,
        height: 1.45,
      ),
      bodySmall: base.textTheme.bodySmall!.copyWith(
        fontSize: 12,
        height: 1.35,
        color: colors.onSurfaceVariant,
      ),
    );
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTokens.cardRadius),
    );
    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: page,
      appBarTheme: AppBarTheme(
        backgroundColor: page,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: content,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: cardShape,
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.onSurfaceVariant,
        textColor: colors.onSurface,
        selectedColor: colors.primary,
        selectedTileColor: colors.primaryContainer,
        shape: cardShape,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: content,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.panelRadius),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: content,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: content,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTokens.panelRadius),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: control,
        selectedColor: colors.primaryContainer,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: content,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: control,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.inputRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.inputRadius),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
      ),
    );
  }
}
