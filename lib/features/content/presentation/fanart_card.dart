import 'package:flutter/material.dart';

import '../../../shared/widgets/media_cover.dart';
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
      ? 36 +
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
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        onSecondaryTap: onLongPress,
        child: Column(
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
              padding: EdgeInsets.fromLTRB(12, textOnly ? 12 : 10, 12, 0),
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
                    fontWeight: textOnly ? FontWeight.normal : FontWeight.w500,
                  ),
                ),
              ),
            ),
            SizedBox(height: textOnly ? 12 : 4),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
      ),
    );
  }
}
