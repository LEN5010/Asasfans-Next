// Reference integration: LoveIwara (MIT), see third_party/LoveIwara-LICENSE.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Chrome uses the reference's light tint and the package's optical defaults.
/// A high-opacity readability veil hides the very backdrop being refracted.
abstract final class AppGlassStyle {
  // Standard is the reference's desktop startup compromise, not evidence of
  // premium backdrop refraction. Unsupported renderers still use clear mode.
  static GlassQuality get quality => switch (defaultTargetPlatform) {
    TargetPlatform.windows || TargetPlatform.linux => GlassQuality.standard,
    _ => GlassQuality.premium,
  };

  static Color tint(Brightness brightness) => brightness == Brightness.dark
      ? Colors.black.withValues(alpha: .24)
      : Colors.white.withValues(alpha: .10);

  static LiquidGlassSettings settings(
    Brightness brightness, {
    double refractiveIndex = 1.2,
    bool shadow = false,
  }) => LiquidGlassSettings(
    glassColor: tint(brightness),
    refractiveIndex: refractiveIndex,
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
