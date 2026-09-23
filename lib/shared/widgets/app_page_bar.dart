import 'package:flutter/material.dart';

import 'glass/app_glass_surface.dart';

/// Floating page controls: a back button, a title pill and one action
/// capsule. Use it with `Scaffold(extendBodyBehindAppBar: true)`; the Scaffold
/// then adds this bar to `MediaQuery.padding.top`, so lists reserve the space
/// inside their own scroll extent (see [pageInsets]).
///
/// The bar slides away while the body scrolls down and returns on the way up,
/// so it never sits on top of what is being read. Its fade appears only once
/// content has scrolled beneath it; at rest the glass sits on the page.
class AppPageBar extends StatefulWidget implements PreferredSizeWidget {
  const AppPageBar({super.key, required this.title, this.actions});
  final Widget title;
  final List<Widget>? actions;

  static const rowHeight = 58.0;
  static const controlHeight = 44.0;

  @override
  Size get preferredSize => const Size.fromHeight(rowHeight);

  @override
  State<AppPageBar> createState() => _AppPageBarState();
}

class _AppPageBarState extends State<AppPageBar> {
  ScrollNotificationObserverState? _observer;
  bool _hidden = false;
  bool _scrolled = false;
  double _scrollTravel = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The Scaffold's own observer sees the body's scrolling, as AppBar's
    // scrolled-under state does.
    final observer = ScrollNotificationObserver.maybeOf(context);
    if (observer != _observer) {
      _observer?.removeListener(_onScroll);
      _observer = observer?..addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _observer?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (metrics.axis != Axis.vertical) return;
    final scrolled = metrics.pixels > metrics.minScrollExtent + 4;
    var hidden = _hidden;
    if (!scrolled) {
      hidden = false;
      _scrollTravel = 0;
    } else if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      // Accumulate travel in one direction, not speed per frame. Slow
      // trackpad gestures must be able to reveal the controls too. Keep the
      // total across wheel events, each of which may start and end a scroll.
      if (delta != 0) {
        if (delta.sign != _scrollTravel.sign) _scrollTravel = 0;
        _scrollTravel += delta;
        if (_scrollTravel.abs() > 6) hidden = _scrollTravel > 0;
      }
    }
    if (hidden != _hidden || scrolled != _scrolled) {
      setState(() {
        _hidden = hidden;
        _scrolled = scrolled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final page = Theme.of(context).scaffoldBackgroundColor;
    final route = ModalRoute.of(context);
    final canPop = route?.impliesAppBarDismissal ?? false;
    final actions = widget.actions ?? const [];
    final title = widget.title;
    const rowHeight = AppPageBar.rowHeight;
    const controlHeight = AppPageBar.controlHeight;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return AnimatedSlide(
      offset: _hidden ? const Offset(0, -1.6) : Offset.zero,
      duration: duration,
      curve: Curves.easeOutCubic,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Hides text scrolled beneath the controls; the glass never sits
          // on the empty region above the window's top edge.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: top + rowHeight + 24,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _scrolled ? 1 : 0,
                duration: duration,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [
                        0,
                        (top + rowHeight * .7) / (top + rowHeight + 24),
                        1,
                      ],
                      colors: [
                        page.withValues(alpha: .95),
                        page.withValues(alpha: .86),
                        page.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(12, top + 10, 12, 4),
            child: IconButtonTheme(
              data: IconButtonThemeData(
                style: IconButton.styleFrom(
                  minimumSize: const Size.square(40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              child: Row(
                children: [
                  if (canPop) ...[
                    AppGlassSurface(
                      radius: controlHeight / 2,
                      child: SizedBox.square(
                        dimension: controlHeight,
                        child: route is PageRoute && route.fullscreenDialog
                            ? const CloseButton()
                            : const BackButton(),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AppGlassSurface(
                        radius: controlHeight / 2,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: controlHeight,
                          ),
                          child: Padding(
                            // Plain titles get a text inset; custom title
                            // controls (channel tabs) bring their own.
                            padding: EdgeInsets.symmetric(
                              horizontal: title is Text ? 16 : 4,
                            ),
                            child: DefaultTextStyle.merge(
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                widthFactor: 1,
                                child: title,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    AppGlassSurface(
                      radius: controlHeight / 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: SizedBox(
                          height: controlHeight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: actions,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// List padding that clears the floating page bar and the bottom navigation,
/// both of which the shell and [AppPageBar] report through MediaQuery. Call it
/// with a context inside the Scaffold body; the page's own context sits
/// outside the Scaffold and does not include the bar.
EdgeInsets pageInsets(
  BuildContext context, {
  double horizontal = 16,
  double top = 8,
  double bottom = 24,
}) {
  final padding = MediaQuery.paddingOf(context);
  return EdgeInsets.fromLTRB(
    horizontal,
    padding.top + top,
    horizontal,
    padding.bottom + bottom,
  );
}
