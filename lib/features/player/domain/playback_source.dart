import '../../../core/domain/bilibili_id.dart';
import '../../../core/domain/request_cancellation.dart';
export '../../../core/domain/request_cancellation.dart';

class PlaybackRequest {
  const PlaybackRequest({
    required this.bvid,
    required this.cid,
    this.quality = 80,
    this.dash = true,
  });
  final String bvid, cid;
  final int quality;
  final bool dash;
  bool get valid =>
      validBvid(bvid) &&
      RegExp(r'^[1-9]\d{0,19}$').hasMatch(cid) &&
      quality > 0 &&
      quality <= 1000;
  PlaybackRequest asMp4() =>
      PlaybackRequest(bvid: bvid, cid: cid, quality: quality, dash: false);
}

class SegmentRange {
  const SegmentRange(this.start, this.end);
  final int start, end;
  String get wire => '$start-$end';
}

/// Signed addresses live only in memory, never in personal snapshots or logs.
class MediaResource {
  MediaResource({required List<Uri> locations, required this.refreshAfter})
    : locations = List.unmodifiable(locations);
  final List<Uri> locations;

  /// Conservative refresh hint, not a guarantee of CDN availability.
  final DateTime refreshAfter;
  @override
  String toString() => 'MediaResource(redacted)';
}

enum DashTrackKind { video, audio }

enum DashAudioGroup { standard, dolby, flac }

class DashTrack {
  const DashTrack({
    required this.kind,
    required this.id,
    required this.codec,
    required this.codecId,
    required this.mime,
    required this.bandwidth,
    required this.resource,
    required this.initialization,
    required this.indexRange,
    this.width,
    this.height,
    this.frameRate,
    this.audioGroup = DashAudioGroup.standard,
  });
  final DashTrackKind kind;
  final int id, codecId, bandwidth;
  final String codec, mime;
  final MediaResource resource;
  final SegmentRange initialization, indexRange;
  final int? width, height;
  final String? frameRate;
  final DashAudioGroup audioGroup;
  @override
  String toString() => 'DashTrack(${kind.name}, $id, redacted)';
}

class Mp4Segment {
  const Mp4Segment({
    required this.order,
    required this.duration,
    required this.resource,
    this.size,
  });
  final int order;
  final Duration duration;
  final int? size;
  final MediaResource resource;
  @override
  String toString() => 'Mp4Segment($order, redacted)';
}

class PlaybackSource {
  PlaybackSource({
    required this.request,
    required this.duration,
    required this.acquiredAt,
    required this.returnedQuality,
    List<DashTrack> video = const [],
    List<DashTrack> audio = const [],
    List<Mp4Segment> mp4 = const [],
  }) : video = List.unmodifiable(video),
       audio = List.unmodifiable(audio),
       mp4 = List.unmodifiable(mp4);
  final PlaybackRequest request;

  /// Duration of the returned source, not proof that a paid/restricted part
  /// was fully acquired. Completion must also consider video-detail metadata.
  final Duration duration;
  final DateTime acquiredAt;
  final int returnedQuality;
  final List<DashTrack> video, audio;
  final List<Mp4Segment> mp4;
  bool get isDash => video.isNotEmpty;
  List<int> get availableQualities => isDash
      ? (video.map((track) => track.id).toSet().toList()
          ..sort((a, b) => b.compareTo(a)))
      : [returnedQuality];
  DateTime get refreshAfter => [
    ...video.map((v) => v.resource.refreshAfter),
    ...audio.map((v) => v.resource.refreshAfter),
    ...mp4.map((s) => s.resource.refreshAfter),
  ].reduce((a, b) => a.isBefore(b) ? a : b);
  DashTrack? videoFor(int quality) {
    if (video.isEmpty) return null;
    final available = availableQualities;
    final selected = available.contains(quality)
        ? quality
        : available.where((q) => q <= quality).firstOrNull ?? available.last;
    final tracks = video.where((v) => v.id == selected).toList()
      ..sort((a, b) {
        int preference(int codec) => switch (codec) {
          7 => 0,
          12 => 1,
          _ => 2,
        };
        final order = preference(a.codecId).compareTo(preference(b.codecId));
        return order == 0 ? b.bandwidth.compareTo(a.bandwidth) : order;
      });
    return tracks.first;
  }

  DashTrack? get defaultAudio {
    if (audio.isEmpty) return null;
    final tracks = [...audio]
      ..sort((a, b) {
        final group = a.audioGroup.index.compareTo(b.audioGroup.index);
        return group == 0 ? b.bandwidth.compareTo(a.bandwidth) : group;
      });
    return tracks.first;
  }

  @override
  String toString() => 'PlaybackSource(${isDash ? 'DASH' : 'MP4'}, redacted)';
}

abstract interface class PlaybackRepository {
  Future<PlaybackSource> acquire(
    PlaybackRequest request, {
    RequestCancellation? cancellation,
  });
}
