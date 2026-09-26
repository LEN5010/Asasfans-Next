import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/media_cover.dart';
import '../../../shared/widgets/media_card_surface.dart';
import '../../creator/presentation/creator_link.dart';
import 'content_images.dart';
import 'dynamic_rich_text.dart';
import '../../library/application/content_snapshots.dart';
import '../../library/presentation/content_actions.dart';
import '../../rules/application/feed_visibility.dart';
import '../domain/fanart_repository.dart';

/// A work tile: the artwork in a stable portrait box with no card frame,
/// then its words, then who made it. A text work shows its words in the
/// same box instead of a fabricated cover. Every tile has the same extent
/// for a given width ([extentFor]), so grids stay fixed and returns land.
class FanartCard extends StatelessWidget {
  const FanartCard({
    required this.item,
    this.onTap,
    this.onLongPress,
    super.key,
  });
  final FanartItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  static bool isText(FanartItem item) =>
      item.contentType == FanartContentType.text ||
      (item.images.isEmpty && item.contentType != FanartContentType.video);

  static double extentFor(FanartItem item, double width, TextScaler scaler) =>
      width / AppTokens.artworkRatio + captionExtent(scaler);

  static double captionExtent(TextScaler scaler) =>
      8 + _titleExtent(scaler) + _bylineExtent(scaler);
  static double _titleExtent(TextScaler scaler) =>
      MediaCardMetrics.line(scaler, 14, 1.4) * 2;
  static double _bylineExtent(TextScaler scaler) =>
      math.max(48, MediaCardMetrics.line(scaler, 12, 1.35) * 2 + 4);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final scaler = MediaQuery.textScalerOf(context);
    final textOnly = isText(item);
    final text = item.text.trim();
    final video = item.contentType == FanartContentType.video;
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

    final members = item.characterTags.map((tag) => tag.wire).join(' · ');
    return MediaActionRegion(
      onTap: onTap,
      onMore: more,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.artworkRadius),
            child: textOnly
                ? AspectRatio(
                    aspectRatio: AppTokens.artworkRatio,
                    child: ColoredBox(
                      color: colors.surfaceContainerHigh,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ExcludeSemantics(
                              child: Text(
                                '“',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: colors.primary,
                                  height: 1,
                                ),
                              ),
                            ),
                            Expanded(
                              // As many whole lines as the box holds, so the
                              // excerpt ends on an ellipsis, never a cut line.
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final style = theme.textTheme.bodyMedium
                                      ?.copyWith(height: 1.6);
                                  final line =
                                      scaler.scale(style?.fontSize ?? 14) * 1.6;
                                  return DynamicRichText(
                                    text: text,
                                    maxLines: math.max(
                                      1,
                                      (constraints.maxHeight / line).floor(),
                                    ),
                                    selectable: false,
                                    style: style,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : MediaCover(
                    image: item.images.firstOrNull,
                    aspectRatio: AppTokens.artworkRatio,
                    // A tile shows a crop; the detail shows the whole image.
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    video: video,
                    badge: video
                        ? '去 B 站看 ↗'
                        : item.images.length > 1
                        ? '${item.images.length} 张'
                        : null,
                  ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: _titleExtent(scaler),
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
                fontWeight: textOnly ? FontWeight.w400 : FontWeight.w500,
                color: textOnly ? colors.onSurfaceVariant : null,
              ),
            ),
          ),
          SizedBox(
            height: _bylineExtent(scaler),
            child: Row(
              children: [
                ContentAvatar(
                  name: item.authorName,
                  image: item.authorAvatarUrl,
                  size: 20,
                ),
                const SizedBox(width: 6),
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
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      if (members.isNotEmpty)
                        Text(
                          members,
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
        ],
      ),
    );
  }
}
