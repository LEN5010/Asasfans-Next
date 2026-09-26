import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../content/domain/community_video_repository.dart';
import '../../content/domain/dynamic_repository.dart';
import '../../content/domain/fanart_repository.dart';
import '../../content/domain/saved_channel.dart';
import '../../content/presentation/dynamic_card.dart' show dynamicTypeLabel;
import '../application/handoff_providers.dart';
import '../domain/return_context.dart';

/// Where 继续挑选 goes, by the channel a snapshot names.
String? browseRoute(String channel) => switch (channel) {
  'fanart' || 'dynamics' => '/content/$channel',
  _ when CommunityChannel.values.any((kind) => kind.name == channel) =>
    '/content/videos?kind=$channel',
  _ => null,
};

/// The snapshot in words: the channel, then its applied conditions, each
/// read back from the committed query the channel itself stored.
List<String> describeBrowse(BrowseSnapshot snapshot) {
  final values = snapshot.query ?? const <String, Object?>{};
  final spec = ChannelSpec(version: ChannelSpec.currentVersion, values: values);
  switch (snapshot.channel) {
    case 'fanart':
      final query = spec.toFanart();
      return [
        '二创',
        for (final member in query.characters) member.wire,
        if (query.category != FanartCategory.all) query.category.wire,
        ...switch (query.contentType) {
          FanartContentType.image => ['图片'],
          FanartContentType.video => ['视频'],
          FanartContentType.text => ['文字'],
          FanartContentType.other => ['其他类型'],
          FanartContentType.all => const <String>[],
        },
        if (query.source == FanartSource.bilibili) 'Bilibili',
        if (query.source == FanartSource.douban) '豆瓣',
        if (query.kind == FanartKind.material) '物料',
        if (query.kind == FanartKind.all) '全部内容',
        ...switch (query.sort) {
          FanartSort.oldest => ['最早'],
          FanartSort.views => ['播放最多'],
          FanartSort.favorites => ['收藏最多'],
          FanartSort.newest => const <String>[],
        },
        if (query.keyword.isNotEmpty) '“${query.keyword}”',
      ];
    case 'dynamics':
      final query = spec.toDynamic();
      return [
        '动态',
        if (query.memberId != null) '指定成员',
        if (query.type != null) dynamicTypeLabel(query.type!),
        if (query.from != null || query.to != null) '已选日期',
        ...switch (query.sort) {
          DynamicSort.oldest => ['最早发布'],
          DynamicSort.likes => ['点赞最多'],
          DynamicSort.comments => ['评论最多'],
          DynamicSort.newest => const <String>[],
        },
        if (query.keyword.isNotEmpty) '“${query.keyword}”',
      ];
  }
  final kind = CommunityChannel.values
      .where((value) => value.name == snapshot.channel)
      .firstOrNull;
  if (kind == null) return const [];
  return [
    kind == CommunityChannel.latest ? '视频' : kind.label,
    if (values['order'] == CommunityVideoOrder.score.name) '最热',
    if (values['withinDays'] == 7) '一周内',
    if (values['withinDays'] == 30) '一月内',
  ];
}

/// 继续挑选: one quiet row back to where picking stopped before the last
/// trip to B站. Absent without a snapshot; dismissing it forgets only the
/// snapshot, never favourites or history. It navigates, never plays.
class ContinueBrowsingRow extends ConsumerWidget {
  const ContinueBrowsingRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handoff = ref.watch(handoffCoordinatorProvider);
    return ListenableBuilder(
      listenable: handoff,
      builder: (context, _) {
        final snapshot = handoff.browsing;
        final route = snapshot == null ? null : browseRoute(snapshot.channel);
        if (snapshot == null || route == null) return const SizedBox.shrink();
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        final where = describeBrowse(snapshot).join(' · ');
        return Padding(
          padding: const EdgeInsets.only(top: AppTokens.itemGap),
          child: Material(
            color: colors.primaryContainer.withValues(alpha: .5),
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () async {
                handoff.resumeBrowsing();
                context.go(route);
                // The feed claims the restore on the frame it is built; one
                // left unclaimed after that is dropped, never kept for later.
                for (var frame = 0; frame < 3; frame++) {
                  await WidgetsBinding.instance.endOfFrame;
                }
                handoff.dropBrowseRestore();
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
                child: Row(
                  children: [
                    Icon(Icons.history, size: 20, color: colors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: '继续挑选：$where',
                        excludeSemantics: true,
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
                                text: where,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                    AppButton.icon(
                      tooltip: '不再显示继续挑选',
                      onPressed: handoff.forgetBrowsing,
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
