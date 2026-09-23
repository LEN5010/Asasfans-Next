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
    return AnimatedContainer(
      duration: AppGlassScope.of(context).canAnimate
          ? AppTokens.pressMotion
          : Duration.zero,
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
    );
  }
}

/// The card's trailing action, pinned to its bottom-right corner. Caption rows
/// beside it keep [reserve] clear so text never runs under the button.
class MediaMoreButton extends StatelessWidget {
  const MediaMoreButton({super.key, required this.onPressed});
  final VoidCallback onPressed;
  static const reserve = 44.0;
  @override
  Widget build(BuildContext context) => AppButton.icon(
    tooltip: '更多操作',
    onPressed: onPressed,
    icon: const Icon(Icons.more_horiz, size: 20),
  );
}
