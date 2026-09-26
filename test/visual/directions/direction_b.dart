import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/shared/widgets/app_controls.dart';
import 'package:flutter/material.dart';

import '../visual_fixture.dart';
import 'proto_common.dart';

/// Direction B · 内容工作台 (prototype). Dense grouped lists, counts in
/// headings, conditions as removable tokens, thumbnails at the row start.
class BTodayPage extends StatelessWidget {
  const BTodayPage({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final events = upcomingEvents().take(4).toList();
    final works = fixtureFanart.take(4).toList();
    return ProtoFrame(
      tab: 0,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          12,
          MediaQuery.paddingOf(context).top + 14,
          12,
          MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '今日 · 9月26日 周六',
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.notifications_none),
                ),
                IconButton(onPressed: () {}, icon: const Icon(Icons.refresh)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _Group(
            title: '日程',
            count: '${events.length} 项',
            children: [
              for (final event in events)
                _Row(
                  leading: SizedBox(
                    width: 64,
                    child: Text(
                      '${dayLabel(event.start) == '今天' ? '' : '${dayLabel(event.start)} '}${hm(event.start)}',
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  title: event.title,
                  trailing: eventStatus(event) ?? '直播',
                ),
            ],
          ),
          _Group(
            title: '进行中',
            children: const [
              _Row(
                leading: Icon(Icons.history, size: 20),
                title: '继续挑选：二创 · 嘉然 · 手书·动画',
                trailing: '回去',
              ),
            ],
          ),
          _Group(
            title: '最新二创',
            count: '${fixtureFanart.length} 件',
            children: [
              for (final item in works)
                _Row(
                  leading: SizedBox.square(
                    dimension: 52,
                    child: item.images.isEmpty
                        ? DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(child: Text('文')),
                          )
                        : ProtoArt(item.images.first, radius: 8),
                  ),
                  title: workTitle(item),
                  subtitle: [
                    item.authorName,
                    members(item),
                    ?workBadge(item),
                  ].where((part) => part.isNotEmpty).join(' · '),
                ),
            ],
          ),
          _Group(
            title: '最新切片',
            count: '${fixtureVideos.length} 条',
            children: [
              for (final video in fixtureVideos.take(3))
                _Row(
                  leading: SizedBox(
                    width: 92,
                    child: ProtoArt(video.coverUrl, ratio: 16 / 9, radius: 6),
                  ),
                  title: video.title,
                  subtitle:
                      '${video.creatorName} · ${duration(video.duration)} · ${views(video.viewCount)}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children, this.count});
  final String title;
  final String? count;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
            child: Row(
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(width: 8),
                if (count != null)
                  Text(count!, style: theme.textTheme.bodySmall),
                const Spacer(),
                Text(
                  '全部',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
          Card(
            child: Column(
              children: [
                for (final (index, child) in children.indexed) ...[
                  if (index > 0) const Divider(height: 1, indent: 12),
                  child,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
  });
  final Widget leading;
  final String title;
  final String? subtitle;
  final String? trailing;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: subtitle == null ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                trailing!,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Direction B · 内容 / 二创 (prototype).
class BFanartPage extends StatelessWidget {
  const BFanartPage({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ProtoFrame(
      tab: 1,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          12,
          MediaQuery.paddingOf(context).top + 12,
          12,
          MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          AppSegments<int>(
            navigation: true,
            values: const [0, 1, 2, 3],
            labelOf: (value) => const ['视频', '二创', '动态', '小说'][value],
            selected: 1,
            onChanged: (_) {},
          ),
          const SizedBox(height: 10),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '搜索二创正文或作者',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              Text('排序：最新', style: theme.textTheme.labelLarge),
              const Icon(Icons.tune, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final token in ['成员：全部', '分类：全部', '类型：全部', '来源：全部'])
                InputChip(
                  label: Text(token),
                  onDeleted: () {},
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                for (final (index, item) in fixtureFanart.indexed) ...[
                  if (index > 0) const Divider(height: 1, indent: 104),
                  _FanartRow(item),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FanartRow extends StatelessWidget {
  const _FanartRow(this.item);
  final FanartItem item;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox.square(
            dimension: 82,
            child: item.images.isEmpty
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text('文字', style: theme.textTheme.labelMedium),
                    ),
                  )
                : ProtoArt(item.images.first, radius: 8),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workTitle(item),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  item.authorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  [
                    members(item),
                    item.category.wire,
                    ?workBadge(item),
                  ].where((part) => part.isNotEmpty).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.more_horiz, size: 18),
        ],
      ),
    );
  }
}
