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
      isText(item)
      ? 28 +
            MediaCardMetrics.line(scaler, 14, 1.45) * 5 +
            MediaCardMetrics.line(scaler, 12, 1.35)
      : width / (item.contentType == FanartContentType.video ? 16 / 9 : 4 / 3) +
            captionExtent(scaler);
  static double captionExtent(TextScaler scaler) =>
      MediaCardMetrics.caption(scaler);

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

    return MediaCardSurface(
      onTap: onTap,
      onMore: more,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!textOnly)
                MediaCover(
                  image: item.images.firstOrNull,
                  aspectRatio: item.contentType == FanartContentType.video
                      ? 16 / 9
                      : 4 / 3,
                  video: item.contentType == FanartContentType.video,
                  badge: item.contentType == FanartContentType.video
                      ? '视频'
                      : item.images.length > 1
                      ? '${item.images.length} 张'
                      : null,
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(12, textOnly ? 10 : 8, 12, 0),
                child: SizedBox(
                  height:
                      MediaCardMetrics.line(scaler, 14, textOnly ? 1.45 : 1.4) *
                      (textOnly ? 5 : 2),
                  child: Text(
                    text.isEmpty
                        ? (textOnly
                              ? '无正文'
                              : item.contentType == FanartContentType.video
                              ? '视频作品'
                              : '图片作品')
                        : text,
                    maxLines: textOnly ? 5 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      height: textOnly ? 1.45 : 1.4,
                      fontWeight: textOnly
                          ? FontWeight.normal
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
              SizedBox(height: textOnly ? 8 : 4),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  12,
                  0,
                  MediaMoreButton.reserve,
                  10,
                ),
                child: SizedBox(
                  height: MediaCardMetrics.line(scaler, 12, 1.35),
                  child: Text(
                    item.authorName.isEmpty ? '未知作者' : item.authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontSize: 12,
                      height: 1.35,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            right: 2,
            bottom: 2,
            child: MediaMoreButton(onPressed: more),
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
            Stack(
              alignment: Alignment.center,
              children: [
                MediaCover(
                  image: item.images.firstOrNull,
                  aspectRatio: 16 / 9,
                  video: true,
                  badge: '视频',
                ),
                AppButton.icon(
                  onPressed: onTap,
                  tooltip: '去 B 站看',
                  icon: const Icon(Icons.play_arrow),
                ),
              ],
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
                const SizedBox(height: 16),
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
                    AppButton(
                      onPressed: onTap,
                      child: Text(video ? '去 B 站看 ↗' : '查看作品'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
