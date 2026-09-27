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

/// A work tile with no card frame, as tall as its own content. An image
/// work is its art in a stable portrait box (the model carries no image
/// sizes), then its words, then who made it. A video work keeps its whole
/// 16:9 cover and its words follow straight after. A text work is a bounded
/// excerpt, not a fabricated cover. Types share the actions and the byline,
/// not a total height: a grid of them is a masonry, and nothing is padded
/// to match a neighbour of another type.
/// The shared tag between a work's tile and its detail page.
Object fanartHeroTag(FanartItem item) => ('fanart-art', item.identity);

class FanartCard extends StatelessWidget {
  const FanartCard({
    required this.item,
    this.onTap,
    this.onLongPress,
    this.heroTag,
    super.key,
  });
  final FanartItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Links the tile's art to the detail's first image, so opening and
  /// closing a work reads as the same picture moving. Only where each work
  /// appears once (the channel grid); see [fanartHeroTag].
  final Object? heroTag;

  static bool isText(FanartItem item) =>
      item.contentType == FanartContentType.text ||
      (item.images.isEmpty && item.contentType != FanartContentType.video);

  /// Video covers are shown whole: a landscape frame cropped into the
  /// portrait box would keep less than half its width.
  static const videoRatio = 16 / 9;

  /// Lines a text work's excerpt may run to in a tile; the rest is in the
  /// detail.
  static const excerptLines = 7;

  static double _bylineExtent(TextScaler scaler) =>
      math.max(48, MediaCardMetrics.line(scaler, 12, 1.35) * 2 + 4);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textOnly = isText(item);
    final text = item.text.trim();
    final video = item.contentType == FanartContentType.video && !textOnly;
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
    final Widget preview;
    if (textOnly) {
      final style = theme.textTheme.bodyMedium?.copyWith(height: 1.6);
      preview = ColoredBox(
        color: colors.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
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
              // A bounded excerpt, ending on an ellipsis; the box is as
              // tall as the words, never a portrait frame to fill.
              DynamicRichText(
                text: text.isNotEmpty ? text : '文字作品',
                maxLines: excerptLines,
                selectable: false,
                style: style,
              ),
            ],
          ),
        ),
      );
    } else {
      preview = _hero(
        context,
        _outlined(
          context,
          cover: video
              ? MediaCover(
                  image: item.images.firstOrNull,
                  aspectRatio: videoRatio,
                  video: true,
                  badge: '去 B 站看 ↗',
                )
              : MediaCover(
                  image: item.images.firstOrNull,
                  aspectRatio: AppTokens.artworkRatio,
                  // A tile shows a crop; the detail shows the whole image.
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  badge: item.images.length > 1
                      ? '${item.images.length} 张'
                      : null,
                ),
        ),
      );
    }
    return MediaActionRegion(
      onTap: onTap,
      onMore: more,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.artworkRadius),
            child: preview,
          ),
          if (!textOnly) ...[
            const SizedBox(height: 8),
            // At most two lines, and only the lines it has: the byline
            // follows the words, whatever the cover above them.
            Text(
              text.isNotEmpty
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
          ],
          _byline(context, members, more),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context, Widget child) {
    final tag = heroTag;
    if (tag == null) return child;
    return HeroMode(
      // Reduced motion: the detail simply appears.
      enabled: !MediaQuery.disableAnimationsOf(context),
      child: Hero(tag: tag, child: child),
    );
  }

  /// A hairline inside the art's edge, so white or very pale art still reads
  /// as a picture on the page rather than dissolving into it.
  Widget _outlined(BuildContext context, {required Widget cover}) =>
      DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTokens.artworkRadius),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: .08),
          ),
        ),
        child: cover,
      );

  Widget _byline(BuildContext context, String members, VoidCallback more) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final scaler = MediaQuery.textScalerOf(context);
    return SizedBox(
      height: _bylineExtent(scaler),
      child: Row(
        children: [
          // Who made it, as one target the height of the line: the avatar,
          // the name and the members together, and no wider than them; the
          // rest of the line still opens the work.
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: CreatorLink(
                mid: item.authorUid,
                minHeight: _bylineExtent(scaler),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ContentAvatar(
                      name: item.authorName,
                      image: item.authorAvatarUrl,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.authorName.isEmpty ? '未知作者' : item.authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurface,
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
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),
          MediaMoreButton(onPressed: more),
        ],
      ),
    );
  }
}
