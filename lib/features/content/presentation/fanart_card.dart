import 'package:flutter/material.dart';

import '../../../shared/widgets/media_cover.dart';
import '../../../shared/widgets/media_card_surface.dart';
import '../../library/application/content_snapshots.dart';
import '../../library/presentation/content_actions.dart';
import '../../rules/application/feed_visibility.dart';
import '../domain/fanart_repository.dart';

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
                padding: EdgeInsets.fromLTRB(
                  12,
                  textOnly ? 10 : 8,
                  textOnly ? 52 : 12,
                  0,
                ),
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
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
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
            top: 0,
            left: textOnly ? null : 0,
            right: textOnly ? 0 : null,
            child: MediaMoreButton(onPressed: more),
          ),
        ],
      ),
    );
  }
}
