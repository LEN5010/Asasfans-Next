// Reference integration: LoveIwara (MIT), see third_party/LoveIwara-LICENSE.
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'app_glass_chrome.dart';
import 'app_glass_scope.dart';
import 'app_glass_style.dart';

/// One bounded chrome surface. The actual content is inside AdaptiveGlass,
/// matching the reference integration, rather than above an empty glass layer.
class AppGlassSurface extends StatefulWidget {
  const AppGlassSurface({
    super.key,
    required this.child,
    this.radius = 24,
    this.nativeContent = false,
    this.refractiveIndex = 1.2,
  });

  final Widget child;
  final double radius;
  final bool nativeContent;

  /// Used by the offline optical comparison; production uses package defaults.
  final double refractiveIndex;

  static Color surfaceColor(Brightness brightness) =>
      brightness == Brightness.dark ? const Color(0xFF222225) : Colors.white;
  static Color foregroundColor(Brightness brightness) =>
      brightness == Brightness.dark
      ? const Color(0xFFF1F0F3)
      : const Color(0xFF25252B);

  @override
  State<AppGlassSurface> createState() => _AppGlassSurfaceState();
}

class _AppGlassSurfaceState extends State<AppGlassSurface> {
  // Material changes reparent this subtree rather than recreating its form,
  // focus or scroll state. There is only one mounted copy of the content.
  final contentKey = GlobalKey();

  @override
  Widget build(BuildContext context) => AppGlassChrome(
    nativeContent: widget.nativeContent,
    builder: (context) {
      final liquid =
          AppGlassScope.of(context).usesLiquid && !widget.nativeContent;
      final brightness = Theme.of(context).brightness;
      final foreground = AppGlassSurface.foregroundColor(brightness);
      final content = KeyedSubtree(
        key: contentKey,
        child: DefaultTextStyle.merge(
          style: TextStyle(color: foreground),
          child: IconTheme.merge(
            data: IconThemeData(color: foreground),
            child: widget.child,
          ),
        ),
      );
      if (liquid) {
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: AppGlassStyle.shadows(brightness),
          ),
          child: AdaptiveGlass(
            quality: AppGlassStyle.quality,
            shape: LiquidRoundedSuperellipse(borderRadius: widget.radius),
            settings: AppGlassStyle.settings(
              brightness,
              refractiveIndex: widget.refractiveIndex,
            ),
            clipExpansion: const EdgeInsets.all(16),
            child: content,
          ),
        );
      }
      return DecoratedBox(
        decoration: BoxDecoration(
          color: AppGlassSurface.surfaceColor(brightness),
          borderRadius: BorderRadius.circular(widget.radius),
          border: Border.all(
            color: brightness == Brightness.dark
                ? const Color(0xFF68656F)
                : const Color(0xFFABA7B2),
          ),
        ),
        child: content,
      );
    },
  );
}
