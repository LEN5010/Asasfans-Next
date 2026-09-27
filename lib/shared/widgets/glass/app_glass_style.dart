// Reference integration: LoveIwara (MIT), see third_party/LoveIwara-LICENSE.
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'app_glass_scope.dart';
import 'glass_policy.dart';

/// Chrome keeps the package's optics (thickness, blur, refraction) with a
/// fixed legible tint, but not its saturation boost or glow: over colourful
/// art those turned the dock into a bright band that competed with its own
/// labels (Impeller renders, reports/layout-perf). A high-opacity veil
/// would hide the very backdrop being refracted, so the tint stays partial.
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
  // At these values the dock's small labels keep 4.5:1 over the fixture's
  // most colourful work at both tiers.
  static Color tint(Brightness brightness) => brightness == Brightness.dark
      ? Colors.black.withValues(alpha: .40)
      : Colors.white.withValues(alpha: .50);

  static LiquidGlassSettings settings(
    Brightness brightness, {
    bool shadow = false,
  }) => LiquidGlassSettings(
    glassColor: tint(brightness),
    // The backdrop as it is, not 1.5x more saturated; a softer rim glow.
    saturation: 1.0,
    glowIntensity: .4,
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
