import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'app_tokens.dart';

abstract final class AppTheme {
  static const dianaPink = Color(0xFFE799B0);
  static const deepRose = Color(0xFF8A3E59);
  static const ink = Color(0xFF451E2C);

  /// Official support colours, keyed by the calendar's member names.
  static const memberColors = <String, Color>{
    'A-SOUL': Color(0xFFFC966E),
    '嘉然': Color(0xFFE799B0),
    '乃琳': Color(0xFF576690),
    '贝拉': Color(0xFFDB7D74),
    '心宜': Color(0xFFC93773),
    '思诺': Color(0xFF7252C0),
  };

  /// Names a member goes by in account names and tags, longest first so
  /// "A-SOUL_Official" is the group, not a member.
  static const _memberNames = <String, List<String>>{
    'A-SOUL': ['a-soul', 'asoul'],
    '嘉然': ['嘉然', 'diana'],
    '乃琳': ['乃琳', 'eileen'],
    '贝拉': ['贝拉', 'bella'],
    '心宜': ['心宜', 'fiona'],
    '思诺': ['思诺', 'gladys'],
  };

  /// The members a name or tag mentions, in [memberColors] order: "心宜&思诺"
  /// is two, "嘉然今天吃什么" one, a fan's own name none.
  static List<String> membersIn(String text) {
    final lower = text.toLowerCase();
    return [
      for (final entry in _memberNames.entries)
        if (entry.value.any(lower.contains)) entry.key,
    ];
  }

  /// Numbers that line up as they change: times, counts, durations.
  static const tabular = [FontFeature.tabularFigures()];

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
          onPrimaryContainer: dark ? const Color(0xFFF6C7D6) : deepRose,
          // Diana pink is the selection and fill colour; ink keeps its text
          // readable. Small accent text stays on [primary] (deep rose in light).
          secondary: dianaPink,
          onSecondary: ink,
          secondaryContainer: dianaPink,
          onSecondaryContainer: ink,
          tertiary: dark ? const Color(0xFFB9A6F2) : const Color(0xFF6A4FB3),
          tertiaryContainer: dark
              ? const Color(0xFF2E2840)
              : const Color(0xFFEFEAFB),
          onTertiaryContainer: dark
              ? const Color(0xFFDCD2FF)
              : const Color(0xFF3F2C78),
          surface: page,
          surfaceDim: dark ? const Color(0xFF0E0D10) : const Color(0xFFEAE7E9),
          surfaceBright: dark ? const Color(0xFF34313A) : Colors.white,
          surfaceContainerLowest: dark ? const Color(0xFF100F12) : Colors.white,
          surfaceContainerLow: content,
          surfaceContainer: content,
          surfaceContainerHigh: control,
          surfaceContainerHighest: dark
              ? const Color(0xFF332F37)
              : const Color(0xFFE9E4E8),
          onSurface: dark ? AppTokens.textDark : AppTokens.textLight,
          onSurfaceVariant: dark
              ? AppTokens.secondaryDark
              : AppTokens.secondaryLight,
          outline: dark ? const Color(0xFF8E8796) : const Color(0xFF8A838F),
          outlineVariant: dark ? AppTokens.dividerDark : AppTokens.dividerLight,
          surfaceTint: Colors.transparent,
          inverseSurface: dark
              ? const Color(0xFFEDEAF0)
              : const Color(0xFF2A2730),
          onInverseSurface: dark ? AppTokens.textLight : AppTokens.textDark,
        );
    final base = ThemeData(useMaterial3: true, colorScheme: colors);
    // Four levels, each with one job: a root page's own title
    // (headlineSmall), a section within a page (titleLarge), an item or
    // compact bar title (titleMedium/titleSmall), and the quiet line of
    // facts under it (bodySmall/label*).
    final text = base.textTheme.copyWith(
      headlineSmall: base.textTheme.headlineSmall!.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        height: 1.18,
      ),
      titleLarge: base.textTheme.titleLarge!.copyWith(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      titleMedium: base.textTheme.titleMedium!.copyWith(
        fontSize: 15.5,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      titleSmall: base.textTheme.titleSmall!.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      bodyLarge: base.textTheme.bodyLarge!.copyWith(fontSize: 15, height: 1.5),
      bodyMedium: base.textTheme.bodyMedium!.copyWith(
        fontSize: 14,
        height: 1.45,
      ),
      bodySmall: base.textTheme.bodySmall!.copyWith(
        fontSize: 12,
        height: 1.35,
        color: colors.onSurfaceVariant,
      ),
      labelLarge: base.textTheme.labelLarge!.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: base.textTheme.labelMedium!.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      labelSmall: base.textTheme.labelSmall!.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: colors.onSurfaceVariant,
      ),
    );
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTokens.cardRadius),
      side: BorderSide(color: colors.outlineVariant.withValues(alpha: .7)),
    );
    final menuShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: page,
      // One page motion on every platform; iOS keeps its slide, which
      // carries the edge swipe back.
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final platform in TargetPlatform.values)
            platform: platform == TargetPlatform.iOS
                ? const CupertinoPageTransitionsBuilder()
                : FadeForwardsPageTransitionsBuilder(backgroundColor: page),
        },
      ),
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
        selectedColor: ink,
        selectedTileColor: dianaPink,
        minTileHeight: 56,
        minLeadingWidth: 24,
        horizontalTitleGap: 12,
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
        dragHandleColor: colors.outline.withValues(alpha: .45),
        dragHandleSize: const Size(36, 4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTokens.panelRadius),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: control,
        selectedColor: dianaPink,
        checkmarkColor: ink,
        side: BorderSide.none,
        shape: const StadiumBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: dianaPink,
          foregroundColor: ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.inputRadius),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) &&
                  !states.contains(WidgetState.disabled)
              ? dianaPink
              : null,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? Colors.transparent : null,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: dianaPink,
        linearTrackColor: dianaPink.withValues(alpha: .22),
        circularTrackColor: Colors.transparent,
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: dianaPink,
        textColor: ink,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: content,
        surfaceTintColor: Colors.transparent,
        shape: menuShape,
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(content),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            menuShape.copyWith(side: BorderSide(color: colors.outlineVariant)),
          ),
          elevation: const WidgetStatePropertyAll(6),
          shadowColor: WidgetStatePropertyAll(
            Colors.black.withValues(alpha: dark ? .5 : .14),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 6),
          ),
        ),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: MenuItemButton.styleFrom(
          minimumSize: const Size(160, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          textStyle: text.bodyMedium,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.inverseSurface.withValues(alpha: .94),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: text.bodySmall?.copyWith(color: colors.onInverseSurface),
        waitDuration: const Duration(milliseconds: 500),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: colors.onInverseSurface,
        ),
        actionTextColor: dark ? deepRose : dianaPink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(4),
        thickness: const WidgetStatePropertyAll(5),
        thumbColor: WidgetStatePropertyAll(
          colors.onSurface.withValues(alpha: .22),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: control,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.inputRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.inputRadius),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
      ),
    );
  }
}
