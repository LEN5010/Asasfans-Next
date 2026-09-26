import '../../rules/application/feed_visibility.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/application/content_snapshots.dart';
import '../../library/presentation/content_actions.dart';
import '../../../core/domain/content_identity.dart';
import '../../library/presentation/library_common.dart';
import '../../../core/time/calendar_time.dart';
import '../../../shared/widgets/media_cover.dart';
import '../../../shared/widgets/media_card_surface.dart';
import '../../../core/domain/video_summary.dart';
import '../../creator/presentation/creator_link.dart';
import '../../handoff/presentation/watch_on_bilibili.dart';

class VideoCard extends ConsumerWidget {
  const VideoCard({
    required this.video,
    this.origin = WatchOrigin.today,
    super.key,
  });
  final VideoSummary video;

  /// Where a return from Bilibili should land. The same card shows up on Today,
  /// in a channel and on a creator page, so the caller owns this.
  final WatchOrigin origin;

  /// Per-item form for shelves that mix card kinds; a video's height never
  /// depends on the video itself.
  static double extentFor(
    VideoSummary video,
    double width,
    TextScaler scaler,
  ) => extentForWidth(width, scaler);

  static double extentForWidth(double width, TextScaler scaler) =>
      width / (16 / 9) +
      MediaCardMetrics.caption(scaler) +
      4 +
      MediaCardMetrics.line(scaler, 11, 1.35);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    void more() => showContentActions(
      context,
      ContentSnapshots.video(video),
      ruleSubject: RuleSubjects.video(video),
    );
    return MediaCardSurface(
      // Videos are watched on Bilibili; the app has no player or detail page.
      onTap: () => video.identity.source == ContentSource.bilibiliVideo
          ? watchOnBilibili(context, ref, video, origin: origin)
          : openContentSource(context, ref, ContentSnapshots.video(video)),
      onMore: more,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MediaCover(
                image: video.coverUrl,
                aspectRatio: 16 / 9,
                video: true,
                badge: video.duration == null
                    ? null
                    : _duration(video.duration!),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: SizedBox(
                  height: MediaCardMetrics.line(scaler, 14, 1.4) * 2,
                  child: Text(
                    video.title,
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
                padding: const EdgeInsets.fromLTRB(
                  12,
                  0,
                  MediaMoreButton.reserve,
                  0,
                ),
                child: SizedBox(
                  height: MediaCardMetrics.line(scaler, 12, 1.35),
                  child: CreatorLink(
                    mid: video.creatorId,
                    child: Text(
                      video.creatorName.isEmpty ? '未知作者' : video.creatorName,
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
              ),
              ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    12,
                    0,
                    MediaMoreButton.reserve,
                    0,
                  ),
                  child: SizedBox(
                    height: MediaCardMetrics.line(scaler, 11, 1.35),
                    child: Text(
                      [
                        if (video.viewCount != null)
                          '${_count(video.viewCount!)} 播放',
                        if (video.publishedAt != null)
                          _date(video.publishedAt!),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 11,
                        height: 1.35,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
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

  static String duration(Duration value) => _duration(value);
  static String count(int value) => _count(value);
  static String date(DateTime value) => _date(value);

  static String _duration(Duration value) {
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return value.inHours > 0
        ? '${value.inHours}:${(value.inMinutes % 60).toString().padLeft(2, '0')}:$seconds'
        : '${value.inMinutes}:$seconds';
  }

  static String _count(int value) =>
      value >= 10000 ? '${(value / 10000).toStringAsFixed(1)}万' : '$value';
  static String _date(DateTime value) {
    final date = CalendarTime.inShanghai(value);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// A video as a list line: a small 16:9 cover, then two lines of title and
/// one of who and when. For places where a few videos accompany other
/// content (Today); the channel keeps [VideoCard]'s grid.
class VideoRow extends ConsumerWidget {
  const VideoRow({
    required this.video,
    this.origin = WatchOrigin.today,
    super.key,
  });
  final VideoSummary video;
  final WatchOrigin origin;

  static const coverWidth = 136.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    void more() => showContentActions(
      context,
      ContentSnapshots.video(video),
      ruleSubject: RuleSubjects.video(video),
    );
    final meta = [
      if (video.viewCount != null) '${VideoCard.count(video.viewCount!)} 播放',
      if (video.publishedAt != null) VideoCard.date(video.publishedAt!),
    ].join(' · ');
    return MediaActionRegion(
      radius: 10,
      onTap: () => video.identity.source == ContentSource.bilibiliVideo
          ? watchOnBilibili(context, ref, video, origin: origin)
          : openContentSource(context, ref, ContentSnapshots.video(video)),
      onMore: more,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: coverWidth,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: MediaCover(
                  image: video.coverUrl,
                  aspectRatio: 16 / 9,
                  video: true,
                  badge: video.duration == null
                      ? null
                      : VideoCard.duration(video.duration!),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  CreatorLink(
                    mid: video.creatorId,
                    child: Text(
                      video.creatorName.isEmpty ? '未知作者' : video.creatorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  if (meta.isNotEmpty)
                    Text(
                      meta,
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
    );
  }
}
