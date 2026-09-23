// Reference integration: LoveIwara (MIT), see third_party/LoveIwara-LICENSE.
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'app_glass_scope.dart';

/// A content-aware foreground, outside GlassContentAwareContent. Only active
/// liquid controls register for sampling; clear/native controls never do.
/// A host must contain just one sampled, Flutter-only background (not chrome).
class AppGlassChrome extends StatelessWidget {
  const AppGlassChrome({
    super.key,
    required this.builder,
    this.nativeContent = false,
  });
  final WidgetBuilder builder;
  final bool nativeContent;

  @override
  Widget build(BuildContext context) {
    if (nativeContent ||
        !AppGlassScope.of(context).usesLiquid ||
        GlassContentAwareScope.maybeOf(context) == null) {
      return builder(context);
    }
    final theme = Theme.of(context);
    return MediaQuery(
      // Seed from the app theme, not the OS theme, which can differ.
      data: MediaQuery.of(
        context,
      ).copyWith(platformBrightness: theme.brightness),
      child: GlassContentAwareBrightness(
        flipDuration: AppGlassScope.of(context).canAnimate
            ? const Duration(milliseconds: 200)
            : Duration.zero,
        builder: (context, brightness, darkAmount) => Theme(
          data: theme.copyWith(
            brightness: brightness,
            colorScheme: theme.colorScheme.copyWith(
              brightness: brightness,
              primary: brightness == Brightness.dark
                  ? const Color(0xFFE799B0)
                  : const Color(0xFF8A3E59),
              onSurface: brightness == Brightness.dark
                  ? const Color(0xFFF1F0F3)
                  : const Color(0xFF25252B),
              onSurfaceVariant: brightness == Brightness.dark
                  ? const Color(0xFFF1F0F3)
                  : const Color(0xFF25252B),
            ),
          ),
          child: Builder(builder: builder),
        ),
      ),
    );
  }
}
