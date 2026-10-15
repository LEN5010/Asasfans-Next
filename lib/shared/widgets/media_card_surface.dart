import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import 'app_controls.dart';
import 'app_motion.dart';
import 'glass/app_glass_scope.dart';

/// One stable content surface. Hover/focus changes its border, never its size.
class MediaCardSurface extends StatefulWidget {
  const MediaCardSurface({
    super.key,
    required this.child,
    this.onTap,
    this.onMore,
  });
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onMore;
  @override
  State<MediaCardSurface> createState() => _MediaCardSurfaceState();
}

class _MediaCardSurfaceState extends State<MediaCardSurface> {
  bool hover = false, focused = false, pressed = false;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTokens.cardRadius),
      side: BorderSide(
        color: focused
            ? colors.primary
            : hover
            ? colors.primary.withValues(alpha: .3)
            : colors.outlineVariant.withValues(alpha: .7),
        width: focused ? 2 : 1,
      ),
    );
    final motion = AppGlassScope.of(context).canAnimate
        ? AppTokens.pressMotion
        : Duration.zero;
    final shadow = AppTokens.cardShadow(colors.brightness);
    // A light press-in; layout keeps the card's size, only paint scales.
    // Under the pointer the card lifts a little further off the page.
    return AnimatedScale(
      scale: pressed ? .98 : 1,
      duration: motion,
      curve: AppCurves.standard,
      child: AnimatedContainer(
        duration: motion * 2,
        curve: AppCurves.standard,
        foregroundDecoration: ShapeDecoration(shape: shape),
        decoration: BoxDecoration(
          color: pressed
              ? Color.alphaBlend(
                  colors.primary.withValues(alpha: .035),
                  colors.surfaceContainerLow,
                )
              : colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppTokens.cardRadius),
          boxShadow: [
            for (final layer in shadow)
              hover
                  ? layer.copyWith(
                      blurRadius: layer.blurRadius * 1.4,
                      offset: layer.offset * 1.5,
                    )
                  : layer,
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.cardRadius),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: widget.onMore,
            onSecondaryTap: widget.onMore,
            onHighlightChanged: (value) => setState(() => pressed = value),
            onHover: (value) => setState(() => hover = value),
            onFocusChange: (value) => setState(() => focused = value),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// The same interaction as [MediaCardSurface] without its visible frame:
/// tap, long-press, right-click, and states drawn just outside the work,
/// never over its words. Under the pointer a soft plate appears around it
/// and a press deepens the plate; keyboard focus is a clear ring. Plate and
/// ring stand [outset] clear of the work, with corners following its own,
/// so a title never sits on an edge. A press also sinks the work in a
/// little. An entry without a tap of its own (selectable prose) shows no
/// hover and no press at all: nothing there is a button.
class MediaActionRegion extends StatefulWidget {
  const MediaActionRegion({
    super.key,
    required this.child,
    this.onTap,
    this.onMore,
    this.radius = AppTokens.artworkRadius,
    this.pressScale = true,
  });
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onMore;
  final double radius;

  /// Whether a press sinks the region in. Off for tall reading entries,
  /// where scaling a block of text only blurs it.
  final bool pressScale;

  /// How far the plate and ring stand outside the work; less than half the
  /// narrowest gap between works, so a neighbour is never overlapped.
  static const outset = 6.0;

  @override
  State<MediaActionRegion> createState() => _MediaActionRegionState();
}

class _MediaActionRegionState extends State<MediaActionRegion> {
  bool focused = false, pressed = false, hovered = false;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final motion = AppGlassScope.of(context).canAnimate
        ? AppTokens.pressMotion
        : Duration.zero;
    // Without a tap there is nothing to activate: no focus stop, no hover
    // and no press, so resting a pointer on prose changes nothing.
    final tappable = widget.onTap != null;
    // A faint wash of the accent rather than grey, so the plate reads as
    // the app's own highlight on the warm page.
    final plate = !tappable
        ? 0.0
        : pressed
        ? .11
        : hovered
        ? .065
        : 0.0;
    return AnimatedScale(
      scale: pressed && tappable && widget.pressScale ? .97 : 1,
      duration: motion,
      curve: AppCurves.standard,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: plate),
        duration: motion * 2,
        curve: AppCurves.standard,
        builder: (context, alpha, child) => CustomPaint(
          painter: _RegionStatePainter(
            fill: colors.primary.withValues(alpha: alpha),
            ring: focused ? colors.primary : null,
            radius: widget.radius,
          ),
          child: child,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            canRequestFocus: tappable,
            // States are the plate and ring, never a block over the words.
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            splashFactory: NoSplash.splashFactory,
            onTap: widget.onTap,
            onLongPress: widget.onMore,
            onSecondaryTap: widget.onMore,
            onHover: tappable
                ? (value) => setState(() => hovered = value)
                : null,
            onHighlightChanged: (value) => setState(() => pressed = value),
            onFocusChange: (value) => setState(() => focused = value),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _RegionStatePainter extends CustomPainter {
  const _RegionStatePainter({
    required this.fill,
    required this.ring,
    required this.radius,
  });
  final Color fill;
  final Color? ring;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    const outset = MediaActionRegion.outset;
    final shape = RRect.fromRectAndRadius(
      (Offset.zero & size).inflate(outset),
      Radius.circular(radius + outset),
    );
    if (fill.a > 0) canvas.drawRRect(shape, Paint()..color = fill);
    if (ring != null) {
      canvas.drawRRect(
        shape.deflate(1),
        Paint()
          ..color = ring!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_RegionStatePainter old) =>
      old.fill != fill || old.ring != ring || old.radius != radius;
}

/// The card's trailing action, pinned to its bottom-right corner. Caption rows
/// beside it keep [reserve] clear so text never runs under the button.
class MediaMoreButton extends StatelessWidget {
  const MediaMoreButton({super.key, required this.onPressed});
  final VoidCallback onPressed;
  static const reserve = 48.0;
  @override
  Widget build(BuildContext context) => AppButton.icon(
    tooltip: '更多操作',
    onPressed: onPressed,
    icon: const Icon(Icons.more_horiz, size: 20),
  );
}
