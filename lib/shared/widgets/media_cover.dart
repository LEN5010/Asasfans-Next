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
    this.alignment = Alignment.center,
    super.key,
  });
  final Uri? image;
  final double aspectRatio;
  final String? badge;
  final bool video;
  final BoxFit fit;

  /// Where a cropped image anchors; tall art keeps its top in view.
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: aspectRatio,
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (image != null)
          // Decoded for the box this cover is drawn in, not a fixed 800: a
          // cropped cover needs enough pixels to fill the height too.
          LayoutBuilder(
            builder: (context, constraints) => Image(
              // Another picture in this place starts over from the tone.
              key: ValueKey(image),
              image: MediaImagePolicy.preview(
                image!,
                logicalWidth: constraints.maxWidth,
                logicalHeight: fit == BoxFit.cover
                    ? constraints.maxHeight
                    : null,
                devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
              ),
              fit: fit,
              alignment: alignment,
              errorBuilder: (_, _, _) => _fallback(context),
              // The same picture resized across a decode size keeps the
              // old decode until the new one is ready, instead of flashing
              // the tone.
              gaplessPlayback: true,
              // A network cover fades in over the loading tone once; a
              // cached one appears at once.
              frameBuilder: (_, child, frame, synchronous) => _Reveal(
                shown: synchronous || frame != null,
                instant: synchronous,
                child: child,
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

/// The loading tone until the first frame, then the image fading in over
/// it, once: later source changes (a resize crossing a decode size) keep
/// what is shown. One child only: an outgoing copy of the image would hold
/// a picture its Image has already released.
class _Reveal extends StatefulWidget {
  const _Reveal({
    required this.shown,
    required this.instant,
    required this.child,
  });
  final bool shown;
  final bool instant;
  final Widget child;
  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(
    vsync: this,
    value: widget.instant ? 1 : 0,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fade.duration = appMotion(context, AppTokens.controlMotion);
    if (widget.shown) _fade.forward();
  }

  @override
  void didUpdateWidget(_Reveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shown) _fade.forward();
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _fade,
    child: widget.child,
    builder: (context, child) => Stack(
      fit: StackFit.expand,
      children: [
        if (_fade.value < 1)
          Opacity(
            opacity: 1 - _fade.value,
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
        Opacity(opacity: _fade.value, child: child),
      ],
    ),
  );
}
