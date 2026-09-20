import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../tools/presentation/tools_sheet.dart';
import 'on_this_day_section.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('今日')),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Image.asset('assets/brand/asasfans.png', width: 56, height: 56),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Asasfans Next',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            LayoutBuilder(
              builder: (context, constraints) => GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: constraints.maxWidth >= 700
                    ? 4
                    : constraints.maxWidth >= 280
                    ? 2
                    : 1,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.2,
                children: [
                  _Entry(
                    '二创档案',
                    Icons.palette_outlined,
                    () => context.go('/content'),
                  ),
                  _Entry(
                    '历史动态',
                    Icons.history,
                    () => context.go('/content/dynamics'),
                  ),
                  _Entry(
                    '直播日历',
                    Icons.calendar_month_outlined,
                    () => context.go('/calendar'),
                  ),
                  _Entry(
                    '社区工具',
                    Icons.widgets_outlined,
                    () => showToolsSheet(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const OnThisDaySection(),
          ],
        ),
      ),
    ),
  );
}

class _Entry extends StatelessWidget {
  const _Entry(this.title, this.icon, this.onTap);
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    ),
  );
}
