import '../../music/presentation/music_widgets.dart';
import 'dart:io' show Platform;

import '../../../shared/theme/app_icons.dart';

import 'package:flutter/material.dart';

import '../../tools/presentation/tools_sheet.dart';
import '../../preferences/application/preferences_controller.dart';
import '../../calendar/presentation/calendar_reminder_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/config/app_version.dart';
import '../../release/application/release_providers.dart';
import '../../release/presentation/release_check.dart';
import '../../../shared/widgets/app_page_bar.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/media_cover.dart';
import '../../../shared/widgets/member_tone.dart';
import '../../../shared/widgets/page_heading.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/app_tokens.dart';
import '../../library/application/library_providers.dart';
import '../../library/domain/library_models.dart';
import '../../library/domain/library_page.dart';
import '../../library/presentation/saved_content_page.dart';
import '../../handoff/presentation/return_entry_tile.dart';
import '../../preferences/presentation/preferences_controls.dart';
import '../../account/application/account_providers.dart';
import '../../account/presentation/local_login_cleanup_tile.dart';
import '../../operations/application/operations_controller.dart';

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

  /// Each entry's badge takes one of the support colours in turn, so a
  /// list of places reads as distinct marks rather than a column of grey.
  static const tones = ['嘉然', '乃琳', '贝拉', '心宜', '思诺', 'A-SOUL'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasLocalLogin = ref.watch(
      accountControllerProvider.select((account) => account.hasLocalLogin),
    );
    List<Widget> links(
      List<(String, String, IconData)> entries, {
      int offset = 0,
    }) => [
      for (final (index, entry) in entries.indexed)
        _Link(
          label: entry.$1,
          icon: entry.$3,
          tone: tones[(index + offset) % tones.length],
          onTap: () => context.go('/mine/${entry.$2}'),
        ),
    ];
    return Scaffold(
      // The shell's backdrop shows through the main pages.
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final gutter = AppTokens.gutter(constraints.maxWidth);
          // The page starts where every page starts, and every block on it
          // shares one right edge, at most [_contentWidth]: the library, the
          // recent row, and the two groups, side by side once both fit.
          final width = constraints.maxWidth - gutter * 2;
          final paired = width >= _groupWidth * 1.4 + AppTokens.sectionGap;
          final manage = _Group(
            title: '管理',
            children: links(const [
              ('订阅管理', 'subscriptions', Icons.person_add_alt),
              ('关注日程', 'calendar-follows', Icons.event_available_outlined),
              ('内容规则', 'rules', Icons.filter_alt_outlined),
              ('备份与恢复', 'backup', Icons.backup_outlined),
            ]),
          );
          final app = _Group(
            title: '应用',
            children: [
              // Only Android has the floating ball; elsewhere the row would be
              // an empty slot between dividers.
              if (Platform.isAndroid) const ReturnEntryTile(),
              _Link(
                label: '设置',
                icon: Icons.tune,
                onTap: () => context.go('/mine/settings'),
              ),
              // A text way into the tools, beside the floating button.
              _Link(
                label: '工具与相关站点',
                icon: Icons.handyman_outlined,
                tone: 'A-SOUL',
                onTap: () => showToolsSheet(context),
              ),
              const _ReleaseLink(),
              const _AnnouncementLink(),
              _Link(
                label: '反馈与帮助',
                icon: Icons.feedback_outlined,
                tone: '乃琳',
                onTap: () => context.go('/mine/support'),
              ),
              // Who made it, whom it thanks, and the licences, on one page.
              _Link(
                label: '关于',
                icon: Icons.info_outline,
                tone: '嘉然',
                onTap: () => context.go('/mine/about'),
              ),
            ],
          );
          Widget bounded(double max, Widget child) => Align(
            alignment: AlignmentDirectional.centerStart,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: max),
              child: child,
            ),
          );
          return ListView(
            padding: EdgeInsets.fromLTRB(
              gutter,
              MediaQuery.paddingOf(context).top + 16,
              gutter,
              MediaQuery.paddingOf(context).bottom + 24,
            ),
            children: [
              bounded(
                _contentWidth,
                RootHeading(
                  title: '我的',
                  actions: [
                    const ThemeToggleButton(),
                    AppButton.icon(
                      tooltip: '设置',
                      onPressed: () => context.go('/mine/settings'),
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ],
                ),
              ),
              // Only while an earlier build's sign-in is still here.
              if (hasLocalLogin) ...[
                const SizedBox(height: AppTokens.sectionGap),
                bounded(
                  _contentWidth,
                  const _Group(
                    title: '账号',
                    children: [LocalLoginCleanupTile()],
                  ),
                ),
              ],
              const SizedBox(height: AppTokens.sectionGap - 8),
              bounded(
                _contentWidth,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeading(title: '我的内容'),
                    const SizedBox(height: 4),
                    _LibraryGrid(
                      entries: _library,
                      onOpen: (path) => context.go('/mine/$path'),
                    ),
                  ],
                ),
              ),
              bounded(_contentWidth, const _RecentSection()),
              const SizedBox(height: AppTokens.sectionGap),
              if (paired)
                bounded(
                  _contentWidth,
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: manage),
                      const SizedBox(width: AppTokens.sectionGap),
                      Expanded(child: app),
                    ],
                  ),
                )
              else ...[
                bounded(_contentWidth, manage),
                const SizedBox(height: AppTokens.sectionGap),
                bounded(_contentWidth, app),
              ],
            ],
          );
        },
      ),
    );
  }

  static const _groupWidth = 520.0;
  static const _contentWidth = _groupWidth * 2 + AppTokens.sectionGap;
}

/// The library as tiles: each a place of my own, reached in one tap. The
/// first two (收藏, 稍后看) are what people come back for, so they lead at a
/// larger size; the rest follow as compact rows. Labels may take two lines,
/// and large text gets fewer columns, so a name is never cut to a stub.
class _LibraryGrid extends StatelessWidget {
  const _LibraryGrid({required this.entries, required this.onOpen});
  final List<(String, String, IconData)> entries;
  final ValueChanged<String> onOpen;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    Widget tile((String, String, IconData) entry, {required bool lead}) {
      final (label, path, icon) = entry;
      final tone =
          MinePage.tones[entries.indexOf(entry) % MinePage.tones.length];
      final text = Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: lead ? theme.textTheme.titleMedium : theme.textTheme.titleSmall,
      );
      // The lead pair is larger, not louder: the same card, more room.
      return AppCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: () => onOpen(path),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: lead
                  ? const EdgeInsets.fromLTRB(16, 16, 12, 16)
                  : const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: lead
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ToneBadge(icon: icon, member: tone, size: 40),
                            const Spacer(),
                            Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: colors.onSurfaceVariant,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        text,
                      ],
                    )
                  : Row(
                      children: [
                        ToneBadge(icon: icon, member: tone),
                        const SizedBox(width: 10),
                        Expanded(child: text),
                      ],
                    ),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        const gap = 10.0;
        final lead = entries.take(2).toList();
        final rest = entries.skip(2).toList();
        final columns = (constraints.maxWidth / (150 * scale.clamp(1.0, 2.5)))
            .floor()
            .clamp(1, 4);
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, entry) in lead.indexed) ...[
                    if (index > 0) const SizedBox(width: gap),
                    Expanded(child: tile(entry, lead: true)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: gap),
            Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final entry in rest)
                  SizedBox(width: width, child: tile(entry, lead: false)),
              ],
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

/// 检查更新, with what the last check found beside it.
class _ReleaseLink extends ConsumerWidget {
  const _ReleaseLink();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final check = ref.watch(releaseCheckProvider);
    final newer = check?.valueOrNull;
    return _Link(
      label: '检查更新',
      icon: Icons.system_update_outlined,
      tone: newer == null ? null : '嘉然',
      detail: switch (check) {
        AsyncLoading() => '正在检查…',
        AsyncData(value: final release?) => '新版本 ${release.version}',
        _ => appVersion,
      },
      highlight: newer != null,
      onTap: check is AsyncLoading ? null : () => checkForUpdates(context, ref),
    );
  }
}

class _AnnouncementLink extends ConsumerWidget {
  const _AnnouncementLink();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(operationsProvider);
    final unread = ref.read(operationsProvider.notifier).unread;
    return _Link(
      label: '公告',
      icon: Icons.campaign_outlined,
      tone: '贝拉',
      detail: unread == 0 ? null : '$unread 条未读',
      highlight: unread > 0,
      onTap: () => context.go('/mine/announcements'),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({
    required this.label,
    required this.icon,
    required this.onTap,
    this.tone,
    this.trailing = Icons.chevron_right,
    this.detail,
    this.highlight = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  /// The member colour of the row's badge; none is a neutral badge.
  final String? tone;
  final IconData trailing;

  /// A short value before the chevron, in the accent when [highlight].
  final String? detail;
  final bool highlight;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 54),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              ToneBadge(icon: icon, member: tone),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
              if (detail != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12, right: 4),
                  child: Text(
                    detail!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: highlight
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: highlight ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              Icon(
                trailing,
                size: trailing == Icons.chevron_right ? 20 : 17,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
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
            children: [
              const _Group(title: '外观与首页', children: [PreferencesControls()]),
              const SizedBox(height: AppTokens.sectionGap),
              _Group(
                title: '音乐',
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: MusicVolumeControl(),
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final state = ref.watch(preferencesControllerProvider);
                      final controller = ref.read(
                        preferencesControllerProvider.notifier,
                      );
                      final on = state.values.musicLoudnessEnabled;
                      return ListTile(
                        leading: const Icon(Icons.graphic_eq),
                        title: const Text('响度均衡'),
                        onTap: state.canEdit
                            ? () => controller.setMusicLoudnessEnabled(!on)
                            : null,
                        trailing: AppSwitch(
                          label: '响度均衡',
                          value: on,
                          onChanged: state.canEdit
                              ? controller.setMusicLoudnessEnabled
                              : null,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.sectionGap),
              const _Group(title: '日历', children: [CalendarReminderSettings()]),
              const SizedBox(height: AppTokens.sectionGap),
              AppCard(
                padding: EdgeInsets.zero,
                child: _Link(
                  label: '免责声明',
                  icon: Icons.info_outline,
                  onTap: () => context.go('/mine/settings/disclaimer'),
                ),
              ),
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
      // Level with the page's other headings and the card's own edge.
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
      ),
      AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0) const Divider(height: 1, indent: 58),
              children[index],
            ],
          ],
        ),
      ),
    ],
  );
}

/// The app itself: its name and version, the author's links, the projects
/// it grew from, and the licences.
class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

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
      for (final (index, entry) in entries.indexed)
        _Link(
          label: entry.$1,
          icon: entry.$3,
          tone: MinePage.tones[index % MinePage.tones.length],
          trailing: Icons.open_in_new,
          onTap: () => open(entry.$2),
        ),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const AppPageBar(title: Text('关于')),
      body: Builder(
        // Inside the body, so MediaQuery carries the page bar height.
        builder: (context) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: pageInsets(context, top: 4),
              children: [
                const _AppIdentity(),
                const SizedBox(height: 20),
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
                const SizedBox(height: 20),
                _Group(
                  title: '许可',
                  children: [
                    _Link(
                      label: '开源许可',
                      icon: Icons.gavel_outlined,
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: 'Asasfans Next',
                        applicationVersion: appVersion,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The app's mark, name and version, at the head of 关于.
class _AppIdentity extends StatelessWidget {
  const _AppIdentity();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              'assets/brand/asasfans.png',
              width: 56,
              height: 56,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Asasfans Next', style: theme.textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(
                  '版本 $appVersion',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFeatures: AppTheme.tabular,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
