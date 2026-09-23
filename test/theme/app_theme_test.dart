import 'package:asasfans_next/app/theme/app_theme.dart';
import 'package:asasfans_next/app/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final theme in [AppTheme.light, AppTheme.dark]) {
    test('${theme.brightness} content surfaces are explicit neutrals', () {
      final c = theme.colorScheme;
      final dark = theme.brightness == Brightness.dark;
      expect(c.surface, dark ? AppTokens.pageDark : AppTokens.pageLight);
      expect(
        theme.cardTheme.color,
        dark ? AppTokens.contentDark : AppTokens.contentLight,
      );
      expect(
        c.surfaceContainerHigh,
        dark ? AppTokens.controlDark : AppTokens.controlLight,
      );
      expect(c.primary, dark ? AppTheme.dianaPink : AppTheme.deepRose);
      expect(theme.inputDecorationTheme.fillColor, c.surfaceContainerHigh);
      for (final background in [
        c.surface,
        c.surfaceContainer,
        c.surfaceContainerHigh,
      ]) {
        final fg = c.onSurface.computeLuminance(),
            bg = background.computeLuminance();
        expect(
          (fg > bg ? (fg + .05) / (bg + .05) : (bg + .05) / (fg + .05)),
          greaterThan(4.5),
        );
      }
    });
  }
}
