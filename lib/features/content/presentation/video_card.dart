import '../../rules/application/feed_visibility.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/application/content_snapshots.dart';
import '../../library/presentation/content_actions.dart';
import '../../../core/domain/content_identity.dart';
import '../../library/presentation/library_common.dart';
import '../../../core/time/calendar_time.dart';
import '../../../core/time/shanghai_date_provider.dart';
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

  /// Built from the same parts the card lays out, so the grid's fixed
  /// extent and the card cannot drift apart.
  static double extentForWidth(double width, TextScaler scaler) =>
      width / (16 / 9) +
      _gap +
      _titleExtent(scaler) +
      2 +
      _metaExtent(scaler) +
      _bylineExtent(scaler);

  static const _gap = 8.0;
  static double _titleExtent(TextScaler scaler) =>
      MediaCardMetrics.line(scaler, 14, 1.4) * 2;
  static double _metaExtent(TextScaler scaler) =>
      MediaCardMetrics.line(scaler, 12, 1.35);

  /// The creator's line is a 48 dp target beside the more button.
  static double _bylineExtent(TextScaler scaler) =>
      math.max(MediaMoreButton.reserve, _metaExtent(scaler) + 8);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    void more() => showContentActions(
      context,
      ContentSnapshots.video(video),
      ruleSubject: RuleSubjects.video(video),
    );
    // No frame: the cover and the words are the card, as with works.
    return MediaActionRegion(
      radius: 10,
      // Videos are watched on Bilibili; the app has no player or detail page.
      onTap: () => video.identity.source == ContentSource.bilibiliVideo
          ? watchOnBilibili(context, ref, video, origin: origin)
          : openContentSource(context, ref, ContentSnapshots.video(video)),
      onMore: more,
      child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: MediaCover(
                  image: video.coverUrl,
                  aspectRatio: 16 / 9,
                  video: true,
                  badge: video.duration == null
                      ? null
                      : _duration(video.duration!),
                ),
              ),
              const SizedBox(height: _gap),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: SizedBox(
                  height: _titleExtent(scaler),
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
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: SizedBox(
                  height: _metaExtent(scaler),
                  child: VideoMeta(video: video),
                ),
              ),
              SizedBox(
                height: _bylineExtent(scaler),
                child: Row(
                  children: [
                    Expanded(
                      child: CreatorLink(
                        mid: video.creatorId,
                        minHeight: _bylineExtent(scaler),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(
                            video.creatorName.isEmpty
                                ? '未知作者'
                                : video.creatorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              height: 1.35,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
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

  /// A short date for a crowded line: 今天, 昨天, 9-24, or 2025-9-24 for an
  /// earlier year. The full date stays in [fullDate] for assistive text.
  static String compactDate(DateTime value, DateTime now) {
    final date = CalendarTime.inShanghai(value);
    final today = CalendarTime.inShanghai(now);
    final day = DateTime.utc(date.year, date.month, date.day);
    final days = DateTime.utc(
      today.year,
      today.month,
      today.day,
    ).difference(day).inDays;
    if (days == 0) return '今天';
    if (days == 1) return '昨天';
    if (date.year == today.year) return '${date.month}-${date.day}';
    return '${date.year}-${date.month}-${date.day}';
  }

  static String fullDate(DateTime value) {
    final date = CalendarTime.inShanghai(value);
    return '${date.year}年${date.month}月${date.day}日';
  }
}

/// Views and a compact date, in one quiet line; read out in full.
class VideoMeta extends ConsumerWidget {
  const VideoMeta({required this.video, super.key});
  final VideoSummary video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(currentTimeProvider)();
    final views = video.viewCount == null
        ? null
        : '${VideoCard.count(video.viewCount!)} 播放';
    final published = video.publishedAt;
    final shown = [
      ?views,
      if (published != null) VideoCard.compactDate(published, now),
    ].join(' · ');
    if (shown.isEmpty) return const SizedBox.shrink();
    return Semantics(
      label: [
        ?views,
        if (published != null) '发布于 ${VideoCard.fullDate(published)}',
      ].join('，'),
      excludeSemantics: true,
      child: Text(
        shown,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 12,
          height: 1.35,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A video as a list line: a 16:9 cover, then two lines of title, the
/// numbers, and who made it. For places where a few videos accompany other
/// content (Today); the channel keeps [VideoCard]'s grid. The cover gives
/// way to the words when the line is narrow or the text large, and above
/// that the video stacks: the title is never left a sliver.
class VideoRow extends ConsumerWidget {
  const VideoRow({
    required this.video,
    this.origin = WatchOrigin.today,
    super.key,
  });
  final VideoSummary video;
  final WatchOrigin origin;

  /// The cover's width for a line [width] wide, or null to stack.
  static double? coverWidthFor(double width, TextScaler scaler) {
    final cover = (width * .36).clamp(96.0, 160.0);
    // What the words keep beside it: about eight characters at least.
    final words = width - cover - 12 - MediaMoreButton.reserve;
    return words >= scaler.scale(14) * 8 ? cover : null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    void more() => showContentActions(
      context,
      ContentSnapshots.video(video),
      ruleSubject: RuleSubjects.video(video),
    );
    final cover = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: MediaCover(
        image: video.coverUrl,
        aspectRatio: 16 / 9,
        video: true,
        badge: video.duration == null
            ? null
            : VideoCard.duration(video.duration!),
      ),
    );
    final words = Column(
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
        VideoMeta(video: video),
      ],
    );
    final byline = Row(
      children: [
        Expanded(
          child: CreatorLink(
            mid: video.creatorId,
            minHeight: MediaMoreButton.reserve,
            child: Text(
              video.creatorName.isEmpty ? '未知作者' : video.creatorName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
        MediaMoreButton(onPressed: more),
      ],
    );
    return MediaActionRegion(
      radius: 10,
      onTap: () => video.identity.source == ContentSource.bilibiliVideo
          ? watchOnBilibili(context, ref, video, origin: origin)
          : openContentSource(context, ref, ContentSnapshots.video(video)),
      onMore: more,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = coverWidthFor(constraints.maxWidth, scaler);
            if (width == null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [cover, const SizedBox(height: 8), words, byline],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: width, child: cover),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [words, byline],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
