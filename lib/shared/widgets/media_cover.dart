import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import 'app_motion.dart';
import 'media_image_policy.dart';

/// Presentation-only CDN transform. Never mutate the URI kept by the model.
Uri displayImageUri(Uri uri, {int width = 640}) {
  final bili = RegExp(
    r'(^|\.)(hdslb\.com|biliimg\.com)$',
    caseSensitive: false,
  );
  if (!bili.hasMatch(uri.host) || !uri.path.startsWith('/bfs/')) return uri;
  final path = uri.path.replaceFirst(RegExp(r'@[^/]*$'), '');
  final format = path.toLowerCase().endsWith('.gif') ? 'gif' : 'webp';
  return uri.replace(path: '$path@${width}w.$format');
}

abstract final class MediaCardMetrics {
  static double line(TextScaler scaler, double size, double height) =>
      (scaler.scale(size) * height).ceilToDouble();
  static double caption(TextScaler scaler) =>
      22 + line(scaler, 14, 1.4) * 2 + line(scaler, 12, 1.35);
}

class MediaCover extends StatelessWidget {
  const MediaCover({
    required this.image,
    required this.aspectRatio,
    this.badge,
    this.video = false,
    this.fit = BoxFit.cover,
    super.key,
  });
  final Uri? image;
  final double aspectRatio;
  final String? badge;
  final bool video;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: aspectRatio,
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (image != null)
          // Decoded for the width this cover is drawn at, not a fixed 800.
          LayoutBuilder(
            builder: (context, constraints) => Image(
              image: MediaImagePolicy.preview(
                image!,
                logicalWidth: constraints.maxWidth,
                devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
              ),
              fit: fit,
              errorBuilder: (_, _, _) => _fallback(context),
              // A network cover cross-fades from the loading tone; a cached
              // one appears at once.
              frameBuilder: (_, child, frame, synchronous) => synchronous
                  ? child
                  : AnimatedSwitcher(
                      duration: appMotion(context, AppTokens.controlMotion),
                      layoutBuilder: (current, previous) => Stack(
                        fit: StackFit.expand,
                        children: [...previous, ?current],
                      ),
                      child: frame == null
                          ? ColoredBox(
                              key: const ValueKey(false),
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                            )
                          : KeyedSubtree(
                              key: const ValueKey(true),
                              child: child,
                            ),
                    ),
            ),
          )
        else
          _fallback(context),
        if (badge != null)
          Positioned(
            right: 8,
            bottom: 8,
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .66),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Text(
                    badge!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _fallback(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Center(
      child: Icon(
        video ? Icons.play_circle_outline : Icons.image_outlined,
        color: Theme.of(context).colorScheme.outline,
        size: 30,
      ),
    ),
  );
}
