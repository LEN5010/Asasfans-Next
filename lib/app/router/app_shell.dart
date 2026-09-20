import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/tools/presentation/tools_sheet.dart';
import '../theme/app_theme.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});
  final StatefulNavigationShell navigationShell;

  static const _labels = ['今日', '内容', '工具', '日历', '我的'];
  static const _icons = [
    Icons.home_outlined,
    Icons.grid_view_outlined,
    Icons.widgets_outlined,
    Icons.calendar_month_outlined,
    Icons.person_outline,
  ];

  @override
  Widget build(BuildContext context) {
    final selected = navigationShell.currentIndex < 2
        ? navigationShell.currentIndex
        : navigationShell.currentIndex + 1;
    void select(int index) {
      if (index == 2) {
        showToolsSheet(context);
        return;
      }
      final branch = index > 2 ? index - 1 : index;
      navigationShell.goBranch(
        branch,
        initialLocation: branch == navigationShell.currentIndex,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 840;
        return Scaffold(
          body: Row(
            children: [
              if (wide) ...[
                SafeArea(
                  child: NavigationRail(
                    extended: constraints.maxWidth >= 1200,
                    selectedIndex: selected,
                    onDestinationSelected: select,
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Image.asset(
                        'assets/brand/asasfans.png',
                        width: 44,
                        height: 44,
                      ),
                    ),
                    destinations: List.generate(
                      _labels.length,
                      (index) => NavigationRailDestination(
                        icon: index == 2
                            ? const _ToolsIcon()
                            : Icon(_icons[index]),
                        label: Text(_labels[index]),
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
              ],
              Expanded(child: navigationShell),
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: selected,
                  onDestinationSelected: select,
                  destinations: List.generate(
                    _labels.length,
                    (index) => NavigationDestination(
                      icon: index == 2
                          ? const _ToolsIcon()
                          : Icon(_icons[index]),
                      label: _labels[index],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _ToolsIcon extends StatelessWidget {
  const _ToolsIcon();

  @override
  Widget build(BuildContext context) => Container(
    width: 46,
    height: 46,
    decoration: BoxDecoration(
      color: AppTheme.dianaPink,
      borderRadius: BorderRadius.circular(17),
      boxShadow: [
        BoxShadow(
          color: AppTheme.deepRose.withValues(alpha: .16),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: const Icon(Icons.widgets_outlined, color: AppTheme.ink),
  );
}
