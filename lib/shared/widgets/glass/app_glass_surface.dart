import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'app_glass_scope.dart';

/// One bounded decorative glass layer behind an unchanged foreground subtree.
/// No per-card capture, screenshot, network state or PlatformView sampling.
class AppGlassSurface extends StatelessWidget {
  const AppGlassSurface({
    super.key,
    required this.child,
    this.radius = 24,
    this.nativeContent = false,
    this.press = 0,
    this.refractiveIndex = 1.22,
  });

  final Widget child;
  final double radius;
  final bool nativeContent;
  final double press;

  /// The prototype compares 1.0 against the default with all other parameters
  /// identical, to distinguish actual displacement from blur/tint alone.
  final double refractiveIndex;

  static Color surfaceColor(Brightness brightness) =>
      brightness == Brightness.dark ? const Color(0xFF222225) : Colors.white;
  static Color foregroundColor(Brightness brightness) =>
      brightness == Brightness.dark
      ? const Color(0xFFF1F0F3)
      : const Color(0xFF25252B);
  static double readabilityOpacity(Brightness brightness) =>
      brightness == Brightness.dark ? .80 : .66;

  @override
  Widget build(BuildContext context) {
    final policy = AppGlassScope.of(context);
    final liquid = policy.usesLiquid && !nativeContent;
    final brightness = Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;
    final surface = surfaceColor(brightness);
    final foreground = foregroundColor(brightness);
    final p = policy.reduceMotion ? 0.0 : press.clamp(0.0, 1.0);
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: liquid
                  ? Transform.scale(
                      scale: 1 - p * .012,
                      child: AdaptiveGlass(
                        quality: GlassQuality.premium,
                        shape: LiquidRoundedSuperellipse(borderRadius: radius),
                        settings: LiquidGlassSettings(
                          thickness: 24 + p * 8,
                          blur: 2,
                          refractiveIndex: refractiveIndex,
                          chromaticAberration: .01,
                          lightIntensity: .6 + p * .12,
                          saturation: 1.05,
                          glassColor: surface.withValues(alpha: .12),
                          shadowElevation: 0,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(radius),
                        border: Border.all(
                          color: dark
                              ? const Color(0xFF68656F)
                              : const Color(0xFFABA7B2),
                        ),
                      ),
                    ),
            ),
          ),
        ),
        // The readable interior is deliberately independent of backdrop
        // sampling. Edge refraction remains visible; text isn't distorted.
        // Keeping this wrapper in BOTH modes preserves focus/scroll/state.
        DecoratedBox(
          decoration: BoxDecoration(
            color: liquid
                ? surface.withValues(alpha: readabilityOpacity(brightness))
                : null,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: foreground),
            child: IconTheme.merge(
              data: IconThemeData(color: foreground),
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}
