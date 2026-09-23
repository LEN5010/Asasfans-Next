import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/tools/presentation/tools_sheet.dart';
import '../../shared/widgets/app_backdrop.dart';
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
      final obstruction = showBottom ? barHeight + 24 : 0.0;
      return AppBackdrop(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          // Nested branch Scaffolds own the keyboard resize; never subtract it twice.
          resizeToAvoidBottomInset: false,
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
                      Stack(
                        fit: StackFit.expand,
                        children: [
                          MediaQuery(
                            data: mq.copyWith(
                              padding: mq.padding.copyWith(
                                bottom: mq.padding.bottom + obstruction,
                              ),
                            ),
                            child: widget.navigationShell,
                          ),
                          // A subtle edge fade under the bar, not an opaque footer.
                          if (showBottom)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              height: mq.padding.bottom + barHeight + 44,
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Theme.of(context)
                                            .scaffoldBackgroundColor
                                            .withValues(alpha: 0),
                                        Theme.of(context)
                                            .scaffoldBackgroundColor
                                            .withValues(alpha: .72),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (showBottom)
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: mq.padding.bottom + 12,
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 520),
                              child: AppGlassNavigation(
                                selected: selected,
                                onSelect: _select,
                                onTools: _tools,
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
