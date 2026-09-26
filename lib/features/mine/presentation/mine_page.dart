import '../../../shared/theme/app_icons.dart';

import 'package:flutter/material.dart';

import '../../tools/presentation/tools_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/app_page_bar.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/media_cover.dart';
import '../../../shared/widgets/page_heading.dart';
import '../../../app/theme/app_tokens.dart';
import '../../library/application/library_providers.dart';
import '../../library/domain/library_models.dart';
import '../../library/domain/library_page.dart';
import '../../library/presentation/saved_content_page.dart';
import '../../preferences/presentation/preferences_controls.dart';
import '../../account/application/account_providers.dart';
import '../../account/presentation/local_login_cleanup_tile.dart';

/// My own content on this device first: the library entries, what I looked
/// at recently, then management and settings. No account centre: the app
/// has no accounts, only local data.
class MinePage extends ConsumerWidget {
  const MinePage({super.key});

  static const _library = [
    ('收藏', 'saved', AppIcons.saved),
    ('稍后看', 'later', Icons.watch_later_outlined),
    ('历史记录', 'history', Icons.history),
    ('继续观看', 'continue', Icons.play_circle_outline),
    ('时间书签', 'bookmarks', AppIcons.bookmark),
    ('应用内更新', 'updates', Icons.notifications_none),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasLocalLogin = ref.watch(
      accountControllerProvider.select((account) => account.hasLocalLogin),
    );
    List<Widget> links(List<(String, String, IconData)> entries) => [
      for (final entry in entries)
        _Link(
          label: entry.$1,
          icon: entry.$3,
          onTap: () => context.go('/mine/${entry.$2}'),
        ),
    ];
    return Scaffold(
      // The shell's backdrop shows through the main pages.
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final gutter = AppTokens.gutter(constraints.maxWidth);
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  gutter,
                  MediaQuery.paddingOf(context).top + 16,
                  gutter,
                  MediaQuery.paddingOf(context).bottom + 24,
                ),
                children: [
                  const RootHeading(
                    title: '我的',
                    subtitle: '收藏、记录和本地资料，都保存在这台设备上',
                  ),
                  // Only while an earlier build's sign-in is still here.
                  if (hasLocalLogin) ...const [
                    SizedBox(height: AppTokens.sectionGap),
                    _Group(title: '账号', children: [LocalLoginCleanupTile()]),
                  ],
                  const SizedBox(height: AppTokens.sectionGap - 8),
                  const SectionHeading(title: '我的内容'),
                  const SizedBox(height: 4),
                  _LibraryGrid(
                    entries: _library,
                    onOpen: (path) => context.go('/mine/$path'),
                  ),
                  const _RecentSection(),
                  const SizedBox(height: AppTokens.sectionGap),
                  _Group(
                    title: '管理',
                    children: links(const [
                      ('订阅管理', 'subscriptions', Icons.person_add_alt),
                      (
                        '关注日程',
                        'calendar-follows',
                        Icons.event_available_outlined,
                      ),
                      ('内容规则', 'rules', Icons.filter_alt_outlined),
                      ('备份与恢复', 'backup', Icons.backup_outlined),
                    ]),
                  ),
                  const SizedBox(height: AppTokens.sectionGap),
                  _Group(
                    title: '应用',
                    children: [
                      ...links(const [('设置', 'settings', Icons.tune)]),
                      // A text way into the tools, beside the floating button.
                      _Link(
                        label: '工具与相关站点',
                        icon: Icons.handyman_outlined,
                        onTap: () => showToolsSheet(context),
                      ),
                      ...links(const [
                        ('作者与致谢', 'credits', Icons.people_outline),
                      ]),
                      _Link(
                        label: '关于',
                        icon: Icons.info_outline,
                        onTap: () => showLicensePage(
                          context: context,
                          applicationName: 'Asasfans Next',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The library as tiles: each a place of my own, reached in one tap.
class _LibraryGrid extends StatelessWidget {
  const _LibraryGrid({required this.entries, required this.onOpen});
  final List<(String, String, IconData)> entries;
  final ValueChanged<String> onOpen;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final columns = (constraints.maxWidth / (110 * scale.clamp(1.0, 2.0)))
            .floor()
            .clamp(2, 6);
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (label, path, icon) in entries)
              SizedBox(
                width: width,
                child: Material(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppTokens.cardRadius),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onOpen(path),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(icon, color: colors.primary),
                          const SizedBox(height: 10),
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// What I looked at last, to pick it up again. Only the first page of the
/// history is read; the section is absent while there is none.
class _RecentSection extends ConsumerWidget {
  const _RecentSection();
  static const _recentWidth = 112.0;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(
      libraryRecordsProvider(const LibraryQuery.history()),
    );
    final recent = records.items.take(8).toList();
    if (recent.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppTokens.sectionGap - 8),
        SectionHeading(
          title: '最近浏览',
          action: '全部',
          onAction: () => context.go('/mine/history'),
        ),
        SizedBox(
          // A square cover plus two caption lines at the current text size.
          height:
              _recentWidth +
              6 +
              (MediaQuery.textScalerOf(context).scale(12) * 1.35).ceil() * 2 +
              4,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recent.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = recent[index].item;
              final image = item.images.firstOrNull;
              return SizedBox(
                width: _recentWidth,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SavedContentPage(item: item),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: image == null
                            ? AspectRatio(
                                aspectRatio: 1,
                                child: ColoredBox(
                                  color: theme.colorScheme.surfaceContainerHigh,
                                  // The title shows below; the box says what
                                  // kind of thing it was, or a line of its body.
                                  child: item.body.isEmpty
                                      ? Icon(
                                          item.kind == LibraryMediaKind.video
                                              ? Icons.play_circle_outline
                                              : Icons.article_outlined,
                                          color: theme.colorScheme.outline,
                                        )
                                      : Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Text(
                                            item.body,
                                            maxLines: 4,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ),
                                ),
                              )
                            : MediaCover(image: image, aspectRatio: 1),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: AppButton(
      onPressed: onTap,
      child: Row(
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
    ),
  );
}

/// The app's settings, moved off the Mine root: appearance, glass and the
/// home modules. Same controls, same stored values.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: const AppPageBar(title: Text('设置')),
    body: Builder(
      // Inside the body, so MediaQuery carries the page bar height.
      builder: (context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: pageInsets(context, top: 4),
            children: const [
              _Group(title: '外观与首页', children: [PreferencesControls()]),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A titled group of rows on one quiet surface.
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
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

/// The author's links and the projects this app grew from.
class CreditsPage extends ConsumerWidget {
  const CreditsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> open(String url) async {
      final opened = await ref
          .read(externalLinkServiceProvider)
          .open(Uri.parse(url));
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('无法打开 $url')));
      }
    }

    List<Widget> rows(List<(String, String, IconData)> entries) => [
      for (final entry in entries)
        Padding(
          padding: const EdgeInsets.all(8),
          child: AppButton(
            onPressed: () => open(entry.$2),
            child: Row(
              children: [
                Icon(entry.$3, size: 22),
                const SizedBox(width: 12),
                Expanded(child: Text(entry.$1)),
                const Icon(Icons.open_in_new, size: 18),
              ],
            ),
          ),
        ),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const AppPageBar(title: Text('作者与致谢')),
      body: Builder(
        // Inside the body, so MediaQuery carries the page bar height.
        builder: (context) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: pageInsets(context, top: 4),
              children: [
                _Group(
                  title: '作者 · LEN5010',
                  children: rows(const [
                    ('GitHub 主页', 'https://github.com/LEN5010', Icons.code),
                    (
                      '哔哩哔哩主页',
                      'https://space.bilibili.com/107261543',
                      Icons.live_tv_outlined,
                    ),
                    (
                      '项目仓库',
                      'https://github.com/LEN5010/Asasfans-Next',
                      Icons.source_outlined,
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                _Group(
                  title: '致谢',
                  children: rows(const [
                    (
                      '原项目 A-SoulFan/as-as-fans',
                      'https://github.com/A-SoulFan/as-as-fans',
                      Icons.history_edu_outlined,
                    ),
                    (
                      'jiarandiana0307 维护的 Fork（2025）',
                      'https://github.com/jiarandiana0307/as-as-fans',
                      Icons.fork_right,
                    ),
                    ('枝江站', 'https://asoul.love/', Icons.favorite_border),
                    (
                      'ASOUL 录音棚',
                      'https://studio.asoul.us.kg/',
                      Icons.mic_none_outlined,
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
