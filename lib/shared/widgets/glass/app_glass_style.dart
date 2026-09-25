// Reference integration: LoveIwara (MIT), see third_party/LoveIwara-LICENSE.
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'app_glass_scope.dart';
import 'glass_policy.dart';

/// Chrome uses the package's optical defaults with a fixed legible tint.
/// A high-opacity readability veil hides the very backdrop being refracted.
abstract final class AppGlassStyle {
  /// The package quality for the scope's effective tier. Solid never
  /// reaches a glass widget; it maps to standard only as a safe default.
  static GlassQuality qualityOf(BuildContext context) =>
      switch (AppGlassScope.of(context).glassTier) {
        GlassTier.premium => GlassQuality.premium,
        GlassTier.standard || GlassTier.solid => GlassQuality.standard,
      };

  // Light chrome carries more white than the reference so its fixed dark
  // text stays legible over any content; controls no longer flip with it.
  static Color tint(Brightness brightness) => brightness == Brightness.dark
      ? Colors.black.withValues(alpha: .24)
      : Colors.white.withValues(alpha: .35);

  static LiquidGlassSettings settings(
    Brightness brightness, {
    bool shadow = false,
  }) => LiquidGlassSettings(
    glassColor: tint(brightness),
    shadow: shadow ? shadows(brightness) : const [],
  );

  static List<BoxShadow> shadows(Brightness brightness) =>
      brightness == Brightness.dark
      ? const []
      : const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ];
}
