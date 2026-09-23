import 'package:flutter/material.dart';

import 'glass/app_glass_controls.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

/// Completes short pages after layout, including empty intermediate pages.
/// Each query, resize or user scroll gets a finite automatic request budget.
class AutoFillViewport extends StatefulWidget {
  const AutoFillViewport({
    required this.controller,
    required this.resetKey,
    required this.canLoadMore,
    required this.onLoadMore,
    required this.child,
    this.scrollResetKey,
    super.key,
  });

  final ScrollController controller;
  final Object resetKey;
  final bool canLoadMore;
  final VoidCallback onLoadMore;
  final Widget child;
  final Object? scrollResetKey;

  @override
  State<AutoFillViewport> createState() => _AutoFillViewportState();
}

class _AutoFillViewportState extends State<AutoFillViewport> {
  static const _pageBudget = 4;
  int _remaining = _pageBudget;
  bool _scheduled = false;
  bool _paused = false;
  Size? _size;
  bool _needsScrollReset = false;

  @override
  void didUpdateWidget(AutoFillViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollResetKey != widget.scrollResetKey) {
      _needsScrollReset = true;
    }
    if (oldWidget.resetKey != widget.resetKey) {
      _remaining = _pageBudget;
      _paused = false;
    }
  }

  void _scheduleCheck() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || !widget.controller.hasClients) {
        return;
      }
      final position = widget.controller.position;
      if (_needsScrollReset && position.hasContentDimensions) {
        _needsScrollReset = false;
        widget.controller.jumpTo(0);
      }
      if (!widget.canLoadMore) return;
      if (!position.hasContentDimensions || position.extentAfter > 400) return;
      if (_remaining == 0) {
        if (!_paused) setState(() => _paused = true);
        return;
      }
      _remaining--;
      widget.onLoadMore();
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      if (_size != size) {
        _size = size;
        _remaining = _pageBudget;
        _paused = false;
      }
      _scheduleCheck();
      return NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth != 0) return false;
          if (notification is UserScrollNotification &&
              notification.direction != ScrollDirection.idle) {
            _remaining = _pageBudget;
            if (_paused) setState(() => _paused = false);
          }
          _scheduleCheck();
          return false;
        },
        // The resume action floats above the bottom navigation instead of
        // taking a row under it, where the shell's bar would cover it.
        child: Stack(
          children: [
            Positioned.fill(child: widget.child),
            if (_paused && widget.canLoadMore)
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.paddingOf(context).bottom + 12,
                child: Center(
                  child: AppGlassButton(
                    onPressed: () {
                      setState(() {
                        _remaining = _pageBudget;
                        _paused = false;
                      });
                      _scheduleCheck();
                    },
                    child: const Text('继续加载'),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
