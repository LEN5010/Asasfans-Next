import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../shared/widgets/media_cover.dart';
import '../../../shared/widgets/media_card_surface.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../creator/presentation/creator_link.dart';
import 'content_images.dart';
import 'dynamic_rich_text.dart';
import '../../library/application/content_snapshots.dart';
import '../../library/presentation/content_actions.dart';
import '../../rules/application/feed_visibility.dart';
import '../domain/fanart_repository.dart';

class FanartCard extends StatelessWidget {
  const FanartCard({
    required this.item,
    this.onTap,
    this.onLongPress,
    this.expanded = false,
    super.key,
  });
  final FanartItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool expanded;

  static bool isText(FanartItem item) =>
      item.contentType == FanartContentType.text ||
      (item.images.isEmpty && item.contentType != FanartContentType.video);
  static double extentFor(FanartItem item, double width, TextScaler scaler) =>
      width / (16 / 9) + captionExtent(scaler);
  static double captionExtent(TextScaler scaler) =>
      20 +
      MediaCardMetrics.line(scaler, 14, 1.4) * 2 +
      math.max(48, MediaCardMetrics.line(scaler, 12, 1.35) * 2 + 2);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textOnly = isText(item);
    final scaler = MediaQuery.textScalerOf(context);
    final text = item.text.trim();
    void more() {
      if (onLongPress != null) {
        onLongPress!();
        return;
      }
      showContentActions(
        context,
        ContentSnapshots.fanart(item),
        ruleSubject: RuleSubjects.fanart(item),
      );
    }

    if (expanded) return _expandedCard(context, more);

    final video = item.contentType == FanartContentType.video;
    return MediaCardSurface(
      onTap: onTap,
      onMore: more,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (textOnly)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(
                color: theme.colorScheme.surfaceContainerHigh,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ClipRect(
                    child: DynamicRichText(text: text, maxLines: 6),
                  ),
                ),
              ),
            )
          else
            MediaCover(
              image: item.images.firstOrNull,
              aspectRatio: 16 / 9,
              fit: video ? BoxFit.cover : BoxFit.contain,
              video: video,
              badge: video
                  ? '去 B 站看 ↗'
                  : item.images.length > 1
                  ? '${item.images.length} 张'
                  : null,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SizedBox(
              height: MediaCardMetrics.line(scaler, 14, 1.4) * 2,
              child: Text(
                textOnly
                    ? '文字作品'
                    : text.isNotEmpty
                    ? text
                    : video
                    ? '视频作品'
                    : '图片作品',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 4, 8),
            child: SizedBox(
              height: math.max(
                48,
                MediaCardMetrics.line(scaler, 12, 1.35) * 2 + 2,
              ),
              child: Row(
                children: [
                  ContentAvatar(
                    name: item.authorName,
                    image: item.authorAvatarUrl,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CreatorLink(
                          mid: item.authorUid,
                          child: Text(
                            item.authorName.isEmpty ? '未知作者' : item.authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        if (item.characterTags.isNotEmpty)
                          Text(
                            item.characterTags
                                .map((tag) => tag.wire)
                                .join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  MediaMoreButton(onPressed: more),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _expandedCard(BuildContext context, VoidCallback more) {
    final theme = Theme.of(context);
    final video = item.contentType == FanartContentType.video;
    return MediaCardSurface(
      onMore: more,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (video)
            InkWell(
              onTap: onTap,
              child: MediaCover(
                image: item.images.firstOrNull,
                aspectRatio: 16 / 9,
                video: true,
                badge: '去 B 站看 ↗',
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ContentAvatar(
                      name: item.authorName,
                      image: item.authorAvatarUrl,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CreatorLink(
                        mid: item.authorUid,
                        child: Text(
                          item.authorName.isEmpty ? '未知作者' : item.authorName,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ),
                    MediaMoreButton(onPressed: more),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final label in {
                      item.category.wire,
                      for (final tag in item.characterTags) tag.wire,
                    })
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(
                            alpha: .5,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          child: Text(
                            label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (!video && item.images.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: ContentImageGallery(images: item.images),
                  ),
                if (item.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: DynamicRichText(text: item.text.trim(), maxLines: 8),
                  ),
                if (!video ||
                    item.viewCount != null ||
                    item.favoriteCount != null) ...[
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (item.viewCount != null)
                        Text(
                          '${item.viewCount} 播放',
                          style: theme.textTheme.bodySmall,
                        ),
                      if (item.favoriteCount != null)
                        Text(
                          '${item.favoriteCount} 收藏',
                          style: theme.textTheme.bodySmall,
                        ),
                      if (!video)
                        AppButton(onPressed: onTap, child: const Text('查看作品')),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
