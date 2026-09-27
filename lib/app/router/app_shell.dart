import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';

import '../../features/tools/presentation/tools_sheet.dart';
import '../../shared/widgets/app_backdrop.dart';
import '../../shared/widgets/app_motion.dart';
import '../../shared/widgets/glass/app_glass_navigation.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    required this.navigationShell,
    required this.isTabRoot,
    super.key,
  });
  final StatefulNavigationShell navigationShell;
  final bool isTabRoot;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool toolsOpen = false;

  Future<void> _tools() async {
    if (toolsOpen) return;
    toolsOpen = true;
    try {
      await showToolsSheet(context);
    } finally {
      toolsOpen = false;
    }
  }

  void _select(int branch) {
    // A navigation tap never resets the branch's saved query/scroll/route.
    if (branch != widget.navigationShell.currentIndex) {
      widget.navigationShell.goBranch(branch);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 840;
      final selected = widget.navigationShell.currentIndex;
      final mq = MediaQuery.of(context);
      final showBottom = !wide && widget.isTabRoot && mq.viewInsets.bottom == 0;
      final barHeight = AppGlassNavigation.heightFor(mq.textScaler);
      return AppBackdrop(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          // Nested branch Scaffolds own the keyboard resize; never subtract it twice.
          resizeToAvoidBottomInset: false,
          // The body runs under the dock, and the Scaffold hands it the
          // dock's height as bottom padding. Always on: switching it would
          // rebuild the body.
          extendBody: true,
          // Here rather than over the body, so a SnackBar sits above it.
          bottomNavigationBar: showBottom
              ? Padding(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    12,
                    12,
                    mq.padding.bottom + 8,
                  ),
                  // The slot's height is loose: as tall as the dock only.
                  child: Align(
                    heightFactor: 1,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: AppGlassNavigation(
                        selected: selected,
                        onSelect: _select,
                        onTools: _tools,
                      ),
                    ),
                  ),
                )
              : null,
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Keep the body at the same element position through breakpoints.
              SizedBox(
                width: wide ? AppSidebar.width + 24 : 0,
                child: wide
                    ? SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          12,
                          mq.padding.top + 10,
                          12,
                          12,
                        ),
                        child: AppSidebar(
                          selected: selected,
                          onSelect: _select,
                          onTools: _tools,
                        ),
                      )
                    : null,
              ),
              Expanded(
                // Isolate branch ModalRoute semantics from the preceding rail.
                child: Semantics(
                  container: true,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      widget.navigationShell,
                      // A subtle edge fade under the bar, not an opaque footer.
                      if (showBottom)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: mq.padding.bottom + barHeight + 40,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Theme.of(context).scaffoldBackgroundColor
                                        .withValues(alpha: 0),
                                    Theme.of(context).scaffoldBackgroundColor
                                        .withValues(alpha: .72),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Keyboard focus scrolls its item into the part of the window nothing
/// floats over. The default reveal lines an item up with the viewport's
/// edge, and a tab root's viewport runs under the status bar and the dock;
/// their heights are the padding that viewport's page receives. Traversal
/// order is the default reading order.
void revealFocusClear(
  FocusNode node, {
  ScrollPositionAlignmentPolicy? alignmentPolicy,
  double? alignment,
  Duration? duration,
  Curve? curve,
}) {
  FocusTraversalPolicy.defaultTraversalRequestFocusCallback(
    node,
    alignmentPolicy: alignmentPolicy,
    alignment: alignment,
    duration: duration,
    curve: curve,
  );
  final context = node.context;
  if (context == null) return;
  final scrollable = Scrollable.maybeOf(context, axis: Axis.vertical);
  final target = context.findRenderObject();
  final viewportBox = scrollable?.context.findRenderObject();
  if (scrollable == null ||
      target == null ||
      !target.attached ||
      viewportBox is! RenderBox ||
      !viewportBox.hasSize) {
    return;
  }
  final viewport = RenderAbstractViewport.maybeOf(target);
  if (viewport == null) return;
  // How much of this viewport the bars cover, from the window's padding.
  final padding = MediaQuery.paddingOf(scrollable.context);
  final window = MediaQuery.sizeOf(scrollable.context).height;
  final top = viewportBox.localToGlobal(Offset.zero).dy;
  final bottom = top + viewportBox.size.height;
  final coverTop = math.max(0.0, padding.top - top);
  final coverBottom = math.max(0.0, bottom - (window - padding.bottom));
  if (coverTop == 0 && coverBottom == 0) return;
  // Scroll offsets at which the item's top meets the viewport's top, and
  // its bottom the viewport's bottom; neither depends on the current one.
  final atTop = viewport.getOffsetToReveal(target, 0).offset;
  final atBottom = viewport.getOffsetToReveal(target, 1).offset;
  final position = scrollable.position;
  var next = position.pixels;
  if (next < atBottom + coverBottom) next = atBottom + coverBottom;
  // Its top wins when the item is taller than the clear part.
  if (next > atTop - coverTop) next = atTop - coverTop;
  next = next.clamp(position.minScrollExtent, position.maxScrollExtent);
  if (next != position.pixels) position.jumpTo(next);
}

/// Main tabs switch with a quick fade-through: the old tab fades out, the
/// new one fades in from 98% scale. Every branch keeps one stable subtree,
/// so its routes, scroll positions and queries survive the switch.
class FadeThroughBranches extends StatefulWidget {
  const FadeThroughBranches({
    required this.currentIndex,
    required this.children,
    super.key,
  });
  final int currentIndex;
  final List<Widget> children;

  @override
  State<FadeThroughBranches> createState() => _FadeThroughBranchesState();
}

class _FadeThroughBranchesState extends State<FadeThroughBranches>
    with SingleTickerProviderStateMixin {
  late final _switch = AnimationController(vsync: this, value: 1);
  late final _incoming = CurvedAnimation(
    parent: _switch,
    curve: const Interval(.3, 1, curve: Curves.easeOutCubic),
  );
  late final _outgoing = ReverseAnimation(
    CurvedAnimation(parent: _switch, curve: const Interval(0, .3)),
  );
  late final _scale = Tween(begin: .98, end: 1.0).animate(_incoming);
  int? _previous;

  @override
  void didUpdateWidget(FadeThroughBranches oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex == widget.currentIndex) return;
    _previous = oldWidget.currentIndex;
    _switch.duration = appMotion(context, const Duration(milliseconds: 260));
    _switch.forward(from: 0).whenCompleteOrCancel(() {
      // A newer switch restarts the controller; only a finished one clears.
      if (mounted && _switch.isCompleted) setState(() => _previous = null);
    });
  }

  @override
  void dispose() {
    _incoming.dispose();
    _switch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      for (final (index, child) in widget.children.indexed)
        _branch(
          child,
          current: index == widget.currentIndex,
          leaving: index == _previous,
        ),
    ],
  );

  // The same wrapper chain in every state; only the animations differ.
  Widget _branch(
    Widget child, {
    required bool current,
    required bool leaving,
  }) => Offstage(
    offstage: !current && !leaving,
    child: IgnorePointer(
      ignoring: !current,
      child: TickerMode(
        enabled: current,
        child: FadeTransition(
          opacity: current
              ? _incoming
              : leaving
              ? _outgoing
              : kAlwaysCompleteAnimation,
          child: ScaleTransition(
            scale: current ? _scale : kAlwaysCompleteAnimation,
            child: child,
          ),
        ),
      ),
    ),
  );
}
