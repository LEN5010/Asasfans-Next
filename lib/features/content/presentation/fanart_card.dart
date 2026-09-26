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

/// A work tile with no card frame. An image work is its art in a stable
/// portrait box, then its words, then who made it. A text work shows its
/// words in the same box instead of a fabricated cover. A video work keeps
/// its whole 16:9 cover and lets its words take the height the cover leaves.
/// Every tile, whatever its type, fills the same extent for a given width
/// ([extentFor]) by construction, so grids stay fixed and returns land.
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

  static double extentFor(FanartItem item, double width, TextScaler scaler) =>
      width / AppTokens.artworkRatio + captionExtent(scaler);

  /// Video covers are shown whole: a landscape frame cropped into the
  /// portrait box would keep less than half its width.
  static const videoRatio = 16 / 9;

  /// The words block of a video tile: what the portrait box and the title
  /// would take, less the 16:9 cover.
  static double videoWordsExtent(double width, TextScaler scaler) =>
      width / AppTokens.artworkRatio -
      width / videoRatio +
      _titleExtent(scaler);

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
    if (video && !textOnly) {
      return MediaActionRegion(
        onTap: onTap,
        onMore: more,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final words = videoWordsExtent(constraints.maxWidth, scaler);
            final line = MediaCardMetrics.line(scaler, 14, 1.4);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTokens.artworkRadius),
                  child: _outlined(
                    context,
                    cover: MediaCover(
                      image: item.images.firstOrNull,
                      aspectRatio: videoRatio,
                      video: true,
                      badge: '去 B 站看 ↗',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // The words take what the shorter cover frees, and the
                // byline sits at the tile's foot, level with its row's
                // neighbours: the middle of the tile stays the work's own.
                SizedBox(
                  height: words,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      text.isNotEmpty ? text : '视频作品',
                      maxLines: math.max(1, (words / line).floor()),
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                _byline(context, members, more),
              ],
            );
          },
        ),
      );
    }
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
                : _hero(
                    context,
                    _outlined(
                      context,
                      cover: MediaCover(
                        image: item.images.firstOrNull,
                        aspectRatio: AppTokens.artworkRatio,
                        // A tile shows a crop; the detail shows the whole
                        // image.
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        badge: item.images.length > 1
                            ? '${item.images.length} 张'
                            : null,
                      ),
                    ),
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
