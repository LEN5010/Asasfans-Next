import 'package:flutter/material.dart';

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
      borderRadius: BorderRadius.circular(14),
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

class MediaMoreButton extends StatelessWidget {
  const MediaMoreButton({super.key, required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    tooltip: '更多操作',
    onPressed: onPressed,
    iconSize: 20,
    style: IconButton.styleFrom(
      backgroundColor: Theme.of(
        context,
      ).colorScheme.surfaceContainerLow.withValues(alpha: .94),
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      minimumSize: const Size.square(48),
    ),
    icon: const Icon(Icons.more_horiz),
  );
}
