import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../features/tools/presentation/tools_sheet.dart';
import '../../shared/theme/app_icons.dart';
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
  final toolsFocus = FocusNode(debugLabel: 'shell-tools');
  bool toolsOpen = false;

  @override
  void dispose() {
    toolsFocus.dispose();
    super.dispose();
  }

  Future<void> _tools() async {
    if (toolsOpen) return;
    toolsOpen = true;
    try {
      await showToolsSheet(context);
    } finally {
      toolsOpen = false;
      if (mounted) toolsFocus.requestFocus();
    }
  }

  void _select(int index) {
    if (index == 2) {
      _tools();
      return;
    }
    final branch = index > 2 ? index - 1 : index;
    // A navigation tap never resets the branch's saved query/scroll/route.
    if (branch != widget.navigationShell.currentIndex) {
      widget.navigationShell.goBranch(branch);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 840;
      final selected = widget.navigationShell.currentIndex < 2
          ? widget.navigationShell.currentIndex
          : widget.navigationShell.currentIndex + 1;
      final mq = MediaQuery.of(context);
      final showBottom = !wide && widget.isTabRoot && mq.viewInsets.bottom == 0;
      final barHeight = AppGlassNavigation.heightFor(mq.textScaler);
      final obstruction = showBottom ? barHeight + 24 : 0.0;
      return Scaffold(
        // Nested branch Scaffolds own the keyboard resize; never subtract it twice.
        resizeToAvoidBottomInset: false,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Keep the body at the same element position through breakpoints.
            SizedBox(
              width: wide ? (constraints.maxWidth >= 1200 ? 184 : 80) : 0,
              child: wide
                  ? AppSidebar(
                      expanded: constraints.maxWidth >= 1200,
                      selected: selected,
                      toolsFocus: toolsFocus,
                      onSelect: _select,
                    )
                  : null,
            ),
            Expanded(
              // Isolate branch ModalRoute semantics from the preceding rail.
              child: Semantics(
                container: true,
                child: GlassContentAwareScope(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      GlassContentAwareContent(
                        child: Stack(
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
                            // Sample the subtle edge fade with the content, never
                            // the controls themselves. It is not an opaque footer.
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
                      ),
                      if (showBottom)
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: mq.padding.bottom + 12,
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 560),
                              child: AppGlassNavigation(
                                selected: selected,
                                onSelect: _select,
                                onTools: _tools,
                                toolsFocus: toolsFocus,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// A neutral desktop sidebar, not a stretched phone glass capsule.
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.expanded,
    required this.selected,
    required this.onSelect,
    required this.toolsFocus,
  });
  final bool expanded;
  final int selected;
  final ValueChanged<int> onSelect;
  final FocusNode toolsFocus;
  static const labels = ['今日', '内容', '工具', '日历', '我的'];
  static const icons = [
    AppIcons.today,
    AppIcons.content,
    AppIcons.tools,
    AppIcons.calendar,
    AppIcons.mine,
  ];
  static const active = [
    AppIcons.todaySelected,
    AppIcons.contentSelected,
    AppIcons.tools,
    AppIcons.calendarSelected,
    AppIcons.mineSelected,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/brand/asasfans_mark.png',
                      width: 36,
                      height: 36,
                    ),
                    if (expanded) ...[
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text(
                          'Asasfans',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              for (var i = 0; i < labels.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Semantics(
                    selected: i == 2 ? null : selected == i,
                    child: TextButton(
                      focusNode: i == 2 ? toolsFocus : null,
                      onPressed: () => onSelect(i),
                      style: TextButton.styleFrom(
                        backgroundColor: selected == i
                            ? colors.primaryContainer
                            : Colors.transparent,
                        foregroundColor: selected == i
                            ? colors.primary
                            : colors.onSurfaceVariant,
                        minimumSize: const Size.fromHeight(56),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: expanded
                          ? Row(
                              children: [
                                Icon(
                                  selected == i ? active[i] : icons[i],
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(labels[i])),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  selected == i ? active[i] : icons[i],
                                  size: 24,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  labels[i],
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
