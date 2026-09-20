import 'package:flutter/material.dart';

abstract final class MediaCardMetrics {
  static double line(TextScaler scaler, double size, double height) =>
      (scaler.scale(size) * height).ceilToDouble();
  static double caption(TextScaler scaler) =>
      26 + line(scaler, 14, 1.4) * 2 + line(scaler, 12, 1.35);
}

class MediaCover extends StatelessWidget {
  const MediaCover({
    required this.image,
    required this.aspectRatio,
    this.badge,
    this.video = false,
    super.key,
  });
  final Uri? image;
  final double aspectRatio;
  final String? badge;
  final bool video;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: aspectRatio,
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (image != null)
          Image.network(
            image.toString(),
            fit: BoxFit.cover,
            cacheWidth: 800,
            errorBuilder: (_, _, _) => _fallback(context),
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : ColoredBox(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),
          )
        else
          _fallback(context),
        if (badge != null)
          Positioned(
            right: 8,
            bottom: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .66),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  badge!,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    height: 1.3,
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
