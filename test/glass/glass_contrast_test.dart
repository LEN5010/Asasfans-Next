import 'dart:math' as math;

import 'package:asasfans_next/shared/widgets/glass/app_glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Analytic lower bound for DEFAULT glyphs, not a claim that every caller's
  // custom color, image or antialiased screenshot has been contrast-accepted.
  for (final brightness in Brightness.values) {
    test('$brightness default glyphs exceed 4.5:1 on worst-case backdrop', () {
      final foreground = AppGlassSurface.foregroundColor(brightness);
      final veil = AppGlassSurface.surfaceColor(
        brightness,
      ).withValues(alpha: AppGlassSurface.readabilityOpacity(brightness));
      for (final backdrop in [
        Colors.black,
        Colors.white,
        const Color(0xFFE799B0),
      ]) {
        final composite = Color.alphaBlend(veil, backdrop);
        final a = foreground.computeLuminance(),
            b = composite.computeLuminance();
        expect(
          (math.max(a, b) + .05) / (math.min(a, b) + .05),
          greaterThanOrEqualTo(4.5),
        );
      }
    });
  }
}
