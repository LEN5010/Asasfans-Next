import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import 'app_controls.dart';
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
            ? colors.primary.withValues(alpha: .28)
            : colors.outlineVariant.withValues(alpha: .55),
      ),
    );
    final motion = AppGlassScope.of(context).canAnimate
        ? AppTokens.pressMotion
        : Duration.zero;
    // A light press-in; layout keeps the card's size, only paint scales.
    return AnimatedScale(
      scale: pressed ? .98 : 1,
      duration: motion,
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: motion,
        foregroundDecoration: ShapeDecoration(shape: shape),
        decoration: BoxDecoration(
          color: pressed
              ? Color.alphaBlend(
                  colors.primary.withValues(alpha: .035),
                  colors.surfaceContainerLow,
                )
              : colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppTokens.cardRadius),
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
/// tap, long-press, right-click, and four states that never wash over the
/// words. Under the pointer a work gets a hairline edge; under keyboard
/// focus a clear ring, so the two are told apart; a press sinks a work in
/// a little. An entry without a tap of its own (selectable prose) shows no
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
  @override
  State<MediaActionRegion> createState() => _MediaActionRegionState();
}

class _MediaActionRegionState extends State<MediaActionRegion> {
  bool focused = false, pressed = false, hovered = false;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(widget.radius);
    final motion = AppGlassScope.of(context).canAnimate
        ? AppTokens.pressMotion
        : Duration.zero;
    // Without a tap there is nothing to activate: no focus stop, no hover
    // and no press, so resting a pointer on prose changes nothing.
    final tappable = widget.onTap != null;
    return AnimatedScale(
      scale: pressed && tappable && widget.pressScale ? .98 : 1,
      duration: motion,
      curve: Curves.easeOutCubic,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          canRequestFocus: tappable,
          // States are drawn as an edge below, never as a grey block.
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          highlightColor: tappable ? null : Colors.transparent,
          splashFactory: tappable ? null : NoSplash.splashFactory,
          onTap: widget.onTap,
          onLongPress: widget.onMore,
          onSecondaryTap: widget.onMore,
          onHover: tappable ? (value) => setState(() => hovered = value) : null,
          onHighlightChanged: (value) => setState(() => pressed = value),
          onFocusChange: (value) => setState(() => focused = value),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: focused
                  ? Border.all(color: colors.primary, width: 2)
                  : hovered
                  ? Border.all(color: colors.primary.withValues(alpha: .32))
                  : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
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
