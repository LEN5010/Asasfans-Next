import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

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
  bool hover = false, focused = false;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTokens.cardRadius),
      side: BorderSide(
        color: focused
            ? colors.primary
            : hover
            ? colors.outline
            : colors.outlineVariant.withValues(alpha: .55),
      ),
    );
    return Material(
      color: colors.surfaceContainerLow,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onMore,
        onSecondaryTap: widget.onMore,
        onHover: (value) => setState(() => hover = value),
        onFocusChange: (value) => setState(() => focused = value),
        child: widget.child,
      ),
    );
  }
}

/// The card's trailing action, pinned to its bottom-right corner. Caption rows
/// beside it keep [reserve] clear so text never runs under the button.
class MediaMoreButton extends StatelessWidget {
  const MediaMoreButton({super.key, required this.onPressed});
  final VoidCallback onPressed;
  static const reserve = 34.0;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: '更多操作',
    onPressed: onPressed,
    iconSize: 20,
    style: IconButton.styleFrom(
      minimumSize: const Size.square(40),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
    icon: const Icon(Icons.more_vert),
  );
}
