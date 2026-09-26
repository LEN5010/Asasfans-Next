import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/features/content/presentation/content_images.dart';
import 'package:flutter/material.dart';

import '../visual_fixture.dart';
import 'proto_common.dart';

/// Direction A · 内容刊 (prototype). Editorial root title; a compact agenda;
/// artworks lead the page; videos as a quiet list; archive last.
class ATodayPage extends StatelessWidget {
  const ATodayPage({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final events = upcomingEvents().take(3).toList();
    final works = fixtureFanart.where((item) => !isTextWork(item)).toList();
    return ProtoFrame(
      tab: 0,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.paddingOf(context).top + 20,
          20,
          MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '9月26日 星期六',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '今天，来枝江看看',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_none),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _Heading('接下来', action: '日历'),
          for (final event in events)
            _AgendaRow(
              time: hm(event.start),
              day: dayLabel(event.start),
              title: event.title,
              status: eventStatus(event),
              color: memberColor(event),
            ),
          const SizedBox(height: 12),
          const _ContinueRow(),
          const SizedBox(height: 24),
          const _Heading('最新二创', action: '查看二创'),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              for (final item in works.take(2)) Expanded(child: AWork(item)),
            ],
          ),
          const SizedBox(height: 28),
          const _Heading('最新切片', action: '全部视频'),
          for (final video in fixtureVideos.take(3))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  SizedBox(
                    width: 136,
                    child: Stack(
                      children: [
                        ProtoArt(video.coverUrl, ratio: 16 / 9, radius: 8),
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: ProtoBadge(duration(video.duration)),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${video.creatorName} · ${relativeTime(video.publishedAt)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          const _Heading('历史上的今天', action: '更多'),
          for (final post in [fixtureDynamics.first, fixtureDynamics.last])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${post.publishedAt!.year} · ${post.member.name}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    post.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, {required this.action});
  final String title;
  final String action;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: () {},
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.chevron_right, size: 18),
          label: Text(action, style: const TextStyle(fontSize: 14)),
        ),
      ],
    );
  }
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({
    required this.time,
    required this.day,
    required this.title,
    required this.status,
    required this.color,
  });
  final String time, day, title;
  final String? status;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final cancelled = status == '已取消';
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  time,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(day, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Container(
            width: 4,
            height: 32,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(
                decoration: cancelled ? TextDecoration.lineThrough : null,
                color: cancelled ? colors.onSurfaceVariant : null,
              ),
            ),
          ),
          if (status != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                status!,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cancelled ? colors.error : colors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ContinueRow extends StatelessWidget {
  const _ContinueRow();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
        child: Row(
          children: [
            Icon(Icons.history, size: 20, color: colors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '继续挑选  ',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                    TextSpan(
                      text: '二创 · 嘉然 · 手书·动画',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.close, size: 18),
              tooltip: '不再显示',
            ),
          ],
        ),
      ),
    );
  }
}

/// A work tile: borderless 4:5 art, then text, then author. Text works get
/// a reading tile of the same box instead of a fake cover.
class AWork extends StatelessWidget {
  const AWork(this.item, {super.key});
  final FanartItem item;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final badge = workBadge(item);
    final text = isTextWork(item);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (text)
          AspectRatio(
            aspectRatio: 4 / 5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '“',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: colors.primary,
                        height: 1,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.text,
                        overflow: TextOverflow.fade,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'serif',
                          height: 1.65,
                        ),
                      ),
                    ),
                    Text('文字作品', style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
            ),
          )
        else
          Stack(
            children: [
              ProtoArt(
                item.images.first,
                ratio: 4 / 5,
                alignment: Alignment.topCenter,
              ),
              if (badge != null)
                Positioned(right: 8, bottom: 8, child: ProtoBadge(badge)),
            ],
          ),
        const SizedBox(height: 8),
        if (!text)
          Text(
            workTitle(item),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        Row(
          children: [
            ContentAvatar(
              name: item.authorName,
              image: item.authorAvatarUrl,
              size: 18,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                item.authorName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            SizedBox.square(
              dimension: 40,
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: () {},
                icon: const Icon(Icons.more_horiz, size: 18),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Direction A · 内容 / 二创 (prototype).
class AFanartPage extends StatelessWidget {
  const AFanartPage({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final items = fixtureFanart;
    return ProtoFrame(
      tab: 1,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.paddingOf(context).top + 16,
              20,
              0,
            ),
            sliver: SliverList.list(
              children: [
                Text(
                  '内容',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const ChannelTabs(selected: 1),
                const SizedBox(height: 12),
                Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search,
                              size: 20,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '搜索二创正文或作者',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox.square(
                      dimension: 44,
                      child: IconButton.filledTonal(
                        onPressed: () {},
                        icon: const Icon(Icons.tune, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '全部成员 · 全部分类 · 最新',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      '${items.length} 件已加载',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              MediaQuery.paddingOf(context).bottom,
            ),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 16,
                mainAxisExtent:
                    (MediaQuery.sizeOf(context).width - 52) / 2 * 5 / 4 +
                    8 +
                    (MediaQuery.textScalerOf(context).scale(14) * 1.4).ceil() *
                        2 +
                    44,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) => AWork(items[index]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Channels as text tabs: selected is bold with a short accent underline.
class ChannelTabs extends StatelessWidget {
  const ChannelTabs({required this.selected, super.key});
  final int selected;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          for (final (index, label) in ['视频', '二创', '动态', '小说'].indexed)
            Padding(
              padding: const EdgeInsets.only(right: 22),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 17,
                      fontWeight: index == selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: index == selected
                          ? colors.onSurface
                          : colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 18,
                    height: 3,
                    decoration: BoxDecoration(
                      color: index == selected
                          ? colors.secondary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
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
