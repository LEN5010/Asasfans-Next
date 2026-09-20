import '../../../core/domain/video_summary.dart';
import '../../../core/domain/request_cancellation.dart';
export '../../../core/domain/request_cancellation.dart';

class VideoPart {
  const VideoPart({
    required this.cid,
    required this.number,
    required this.title,
    this.duration,
  });
  final String cid;
  final int number;
  final String title;
  final Duration? duration;
}

class VideoDetail {
  VideoDetail({
    required this.video,
    required this.aid,
    required List<VideoPart> parts,
    this.replyCount,
    this.favoriteCount,
    this.coinCount,
    this.shareCount,
    this.interactive = false,
    this.redirectUrl,
  }) : parts = List.unmodifiable(parts);
  final VideoSummary video;
  final String aid;
  final List<VideoPart> parts;
  final int? replyCount, favoriteCount, coinCount, shareCount;
  final bool interactive;
  final Uri? redirectUrl;
  Uri partUrl(VideoPart part) =>
      video.bilibiliUrl.replace(queryParameters: {'p': '${part.number}'});
}

abstract interface class VideoRepository {
  Future<VideoDetail> detail(String bvid, {RequestCancellation? cancellation});
}
