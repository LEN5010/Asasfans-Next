import '../../../shared/theme/app_icons.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_page_bar.dart';
import '../../../shared/widgets/glass/app_glass_controls.dart';
import '../../preferences/presentation/preferences_controls.dart';
import '../../account/application/account_providers.dart';
import '../../account/presentation/local_login_cleanup_tile.dart';

class MinePage extends ConsumerStatefulWidget {
  const MinePage({super.key});
  @override
  ConsumerState<MinePage> createState() => _MinePageState();
}

class _MinePageState extends ConsumerState<MinePage> {
  int _section = 0;
  @override
  Widget build(BuildContext context) {
    final hasLocalLogin = ref.watch(
      accountControllerProvider.select((account) => account.hasLocalLogin),
    );
    List<Widget> links(List<(String, String, IconData)> entries) => [
      for (final entry in entries)
        Padding(
          padding: const EdgeInsets.all(8),
          child: AppGlassButton(
            onPressed: () => context.go('/mine/${entry.$2}'),
            child: Row(
              children: [
                Icon(entry.$3, size: 22),
                const SizedBox(width: 12),
                Expanded(child: Text(entry.$1)),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
          ),
        ),
    ];
    final groups = [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Only while an earlier build's sign-in is still on this device.
          if (hasLocalLogin) ...const [
            _SettingsGroup(title: '账号', children: [LocalLoginCleanupTile()]),
            SizedBox(height: 20),
          ],
          _SettingsGroup(
            title: '我的内容',
            children: links(const [
              ('收藏', 'saved', AppIcons.saved),
              ('稍后看', 'later', Icons.watch_later_outlined),
              ('继续观看', 'continue', Icons.play_circle_outline),
              ('时间书签', 'bookmarks', AppIcons.bookmark),
              ('历史记录', 'history', Icons.history),
            ]),
          ),
          const SizedBox(height: 20),
          _SettingsGroup(
            title: '订阅与日程',
            children: links(const [
              ('应用内更新', 'updates', Icons.notifications_none),
              ('订阅管理', 'subscriptions', Icons.person_add_alt),
              ('关注日程', 'calendar-follows', Icons.event_available_outlined),
            ]),
          ),
          const SizedBox(height: 20),
          _SettingsGroup(
            title: '资料管理',
            children: links(const [
              ('内容规则', 'rules', Icons.filter_alt_outlined),
              ('备份与恢复', 'backup', Icons.backup_outlined),
            ]),
          ),
        ],
      ),
      const _SettingsGroup(title: '偏好', children: [PreferencesControls()]),
      _SettingsGroup(
        title: '应用',
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: AppGlassButton(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'Asasfans Next',
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 12),
                  Expanded(child: Text('关于')),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ],
      ),
    ];
    return Scaffold(
      extendBodyBehindAppBar: true,
      // The shell's backdrop shows through the main pages.
      backgroundColor: Colors.transparent,
      appBar: const AppPageBar(title: Text('我的')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 900) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 192,
                  child: ListView(
                    key: const ValueKey('mine-sections'),
                    padding: pageInsets(context, horizontal: 12),
                    children: [
                      for (final entry in const [
                        (0, '个人资料', Icons.person_outline),
                        (1, '偏好', Icons.tune),
                        (2, '应用', Icons.apps_outlined),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AppGlassButton(
                            selected: _section == entry.$1,
                            onPressed: () =>
                                setState(() => _section = entry.$1),
                            child: Row(
                              children: [
                                Icon(entry.$3),
                                const SizedBox(width: 10),
                                Expanded(child: Text(entry.$2)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: ListView(
                        padding: pageInsets(context, horizontal: 24),
                        children: [groups[_section]],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          return ListView(
            padding: pageInsets(context),
            children: [
              for (final group in groups)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: group,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 10),
        child: Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      Card(
        clipBehavior: Clip.antiAlias,
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Column(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0) const Divider(height: 1, indent: 56),
              children[index],
            ],
          ],
        ),
      ),
    ],
  );
}
