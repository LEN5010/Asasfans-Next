import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:flutter/material.dart';

import '../visual_fixture.dart';
import 'direction_a.dart' show ChannelTabs;
import 'proto_common.dart';

/// Direction C · 作品展廊 (prototype). A full-bleed lead artwork carries the
/// date; a one-line schedule; large tiles; captions mostly off the grid.
class CTodayPage extends StatelessWidget {
  const CTodayPage({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final lead = fixtureFanart.first;
    final next = upcomingEvents().first;
    final width = MediaQuery.sizeOf(context).width;
    return ProtoFrame(
      tab: 0,
      child: ListView(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        children: [
          SizedBox(
            height: width * 1.15,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ProtoArt(lead.images.first, radius: 0),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xB3000000)],
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '9月26日 · 今天',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${workTitle(lead)}\n— ${lead.authorName}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: .9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: memberColor(next),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${hm(next.start)}  ${next.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            child: Text(
              '继续挑选 · 二创 · 嘉然 · 手书·动画',
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '更多作品',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 300,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final item
                    in fixtureFanart
                        .skip(1)
                        .where((item) => item.images.isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: SizedBox(
                      width: 225,
                      child: _Tile(item, caption: true),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '新鲜切片',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final video in fixtureVideos.take(2))
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProtoArt(video.coverUrl, ratio: 16 / 9),
                  const SizedBox(height: 6),
                  Text(video.title, style: theme.textTheme.titleSmall),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.item, {this.caption = false});
  final FanartItem item;
  final bool caption;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badge = workBadge(item);
    final art = isTextWork(item)
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(caption ? 14 : 4),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                item.text,
                overflow: TextOverflow.fade,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'serif',
                  height: 1.6,
                ),
              ),
            ),
          )
        : ProtoArt(
            item.images.first,
            radius: caption ? 14 : 4,
            alignment: Alignment.topCenter,
          );
    return Stack(
      fit: StackFit.expand,
      children: [
        art,
        if (badge != null)
          Positioned(right: 8, top: 8, child: ProtoBadge(badge)),
        if (caption)
          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: Text(
              item.authorName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.white,
                shadows: const [Shadow(blurRadius: 6)],
              ),
            ),
          ),
      ],
    );
  }
}

/// Direction C · 内容 / 二创 (prototype): an edge-to-edge wall, search and
/// conditions behind one floating button.
class CFanartPage extends StatelessWidget {
  const CFanartPage({super.key});
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ProtoFrame(
      tab: 1,
      child: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  MediaQuery.paddingOf(context).top + 10,
                  16,
                  8,
                ),
                sliver: const SliverToBoxAdapter(
                  child: ChannelTabs(selected: 1),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.only(bottom: bottom),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 3,
                    mainAxisSpacing: 3,
                    childAspectRatio: 4 / 5,
                  ),
                  itemCount: fixtureFanart.length,
                  itemBuilder: (context, index) => _Tile(fixtureFanart[index]),
                ),
              ),
            ],
          ),
          Positioned(
            right: 16,
            bottom: bottom - 12,
            child: FilledButton.tonalIcon(
              onPressed: () {},
              icon: const Icon(Icons.tune),
              label: const Text('搜索与筛选'),
            ),
          ),
        ],
      ),
    );
  }
}
