import 'package:flutter/material.dart';

import 'glass/app_glass_surface.dart';

/// Floating page controls: a back button, a title pill and one action
/// capsule over a faded top edge. Use it with
/// `Scaffold(extendBodyBehindAppBar: true)`; the Scaffold then adds this bar to
/// `MediaQuery.padding.top`, so lists reserve the space inside their own
/// scroll extent (see [pageInsets]) and scroll on underneath the controls.
class AppPageBar extends StatelessWidget implements PreferredSizeWidget {
  const AppPageBar({super.key, required this.title, this.actions});
  final Widget title;
  final List<Widget>? actions;

  static const rowHeight = 58.0;
  static const controlHeight = 44.0;

  @override
  Size get preferredSize => const Size.fromHeight(rowHeight);

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final page = Theme.of(context).scaffoldBackgroundColor;
    final route = ModalRoute.of(context);
    final canPop = route?.impliesAppBarDismissal ?? false;
    final actions = this.actions ?? const [];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Nearly solid behind the controls, then a short fade: text scrolling
        // up never reads through a title, and the glass never samples the
        // empty region above the window's top edge.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: top + rowHeight + 24,
          child: IgnorePointer(
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
                    page.withValues(alpha: .97),
                    page.withValues(alpha: .9),
                    page.withValues(alpha: 0),
                  ],
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
    );
  }
}

/// List padding that clears the floating page bar and the bottom navigation,
/// both of which the shell and [AppPageBar] report through MediaQuery.
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
