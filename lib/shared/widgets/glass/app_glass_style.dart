// Reference integration: LoveIwara (MIT), see third_party/LoveIwara-LICENSE.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Chrome uses the package's optical defaults with a fixed legible tint.
/// A high-opacity readability veil hides the very backdrop being refracted.
abstract final class AppGlassStyle {
  // Standard is the reference's desktop startup compromise, not evidence of
  // premium backdrop refraction. Unsupported renderers still use clear mode.
  static GlassQuality get quality => switch (defaultTargetPlatform) {
    TargetPlatform.windows || TargetPlatform.linux => GlassQuality.standard,
    _ => GlassQuality.premium,
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
