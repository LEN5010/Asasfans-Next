import 'content_identity.dart';

/// Public video metadata; no playback URLs or account credentials.
class VideoSummary {
  const VideoSummary({
    required this.identity,
    required this.title,
    required this.creatorName,
    required this.creatorId,
    this.coverUrl,
    this.creatorAvatarUrl,
    this.description = '',
    this.category = '',
    this.tags,
    this.publishedAt,
    this.duration,
    this.viewCount,
    this.likeCount,
    this.rankScore,
  });

  final ContentIdentity identity;
  final String title;
  final String creatorName;
  final String creatorId;
  final Uri? coverUrl;
  final Uri? creatorAvatarUrl;
  final String description;

  /// Bilibili's own partition name, not this app's classification.
  final String category;
  final List<String>? tags;
  final DateTime? publishedAt;
  final Duration? duration;
  final int? viewCount;
  final int? likeCount;

  /// Source ranking metric, used only to merge independently ranked streams.
  final num? rankScore;

  Uri get bilibiliUrl => Uri(
    scheme: 'https',
    host: 'www.bilibili.com',
    pathSegments: ['video', identity.value],
  );
}
