import '../../../core/bilibili/bili_metadata_client.dart';
import '../../../core/bilibili/bili_media_policy.dart';
import '../../../core/bilibili/bili_value.dart';
import '../../../core/network/api_failure.dart';
import '../domain/playback_source.dart';

class BiliPlaybackRepository implements PlaybackRepository {
  BiliPlaybackRepository(this._gateway, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final BiliReadGateway _gateway;
  final DateTime Function() _clock;
  @override
  Future<PlaybackSource> acquire(
    PlaybackRequest request, {
    RequestCancellation? cancellation,
  }) async {
    if (!request.valid) throw const ApiFailure(ApiFailureKind.invalidRequest);
    final data = await _gateway.get(
      BiliReadEndpoint.playUrl,
      parameters: {
        'bvid': request.bvid,
        'cid': request.cid,
        'qn': '${request.quality}',
        'fnval': request.dash ? '4048' : '1',
        'fnver': '0',
        'fourk': '1',
        'otype': 'json',
        'platform': 'pc',
        'gaia_source': 'view-card',
      },
      cancellation: cancellation,
    );
    return decode(data, request, _clock().toUtc());
  }

  static PlaybackSource decode(
    Map<String, Object?> data,
    PlaybackRequest request,
    DateTime now,
  ) {
    if ((data['bvid'] != null && data['bvid'] != request.bvid) ||
        (data['cid'] != null && BiliValue.id(data['cid']) != request.cid)) {
      BiliValue.invalid();
    }
    if (data['v_voucher'] != null || data['is_risk'] == true) {
      throw const ApiFailure(ApiFailureKind.riskControl);
    }
    final length = BiliValue.integer(data['timelength']);
    final quality = BiliValue.integer(data['quality']);
    if (length <= 0 || length > 604800000 || quality <= 0 || quality > 1000) {
      BiliValue.invalid();
    }
    final duration = Duration(milliseconds: length);
    final rawDash = data['dash'];
    if (rawDash != null) {
      final dash = BiliValue.map(rawDash);
      final video = _tracks(dash['video'], DashTrackKind.video, now);
      final audio = <DashTrack>[
        ..._tracks(dash['audio'], DashTrackKind.audio, now),
        if (dash['dolby'] != null)
          ..._tracks(
            BiliValue.map(dash['dolby'])['audio'],
            DashTrackKind.audio,
            now,
            group: DashAudioGroup.dolby,
          ),
        if (dash['flac'] != null &&
            BiliValue.map(dash['flac'])['audio'] != null)
          ..._tracks(
            [BiliValue.map(dash['flac'])['audio']],
            DashTrackKind.audio,
            now,
            group: DashAudioGroup.flac,
          ),
      ];
      final rawDuration = dash['duration'];
      var dashDuration = duration;
      if (rawDuration != null) {
        if (rawDuration is! num ||
            !rawDuration.isFinite ||
            rawDuration <= 0 ||
            rawDuration > 604800) {
          BiliValue.invalid();
        }
        dashDuration = Duration(milliseconds: (rawDuration * 1000).round());
      }
      if (video.isNotEmpty) {
        return PlaybackSource(
          request: request,
          duration: dashDuration,
          acquiredAt: now,
          returnedQuality: quality,
          video: video,
          audio: audio,
        );
      }
    }
    // A returned MP4 is a valid fallback. Do not silently turn API failures or
    // malformed DASH into repeated MP4 requests or take only the first segment.
    final raw = data['durl'];
    if (data['format'] is! String ||
        !(data['format'] as String).startsWith('mp4') ||
        raw is! List ||
        raw.isEmpty ||
        raw.length > 1000) {
      throw const ApiFailure(
        ApiFailureKind.unavailable,
        code: 'UNSUPPORTED_MEDIA_FORMAT',
      );
    }
    final segments = <Mp4Segment>[];
    for (final entry in raw) {
      final row = BiliValue.map(entry);
      final order = BiliValue.integer(row['order']);
      final milliseconds = BiliValue.integer(row['length']);
      if (order != segments.length + 1 ||
          milliseconds <= 0 ||
          milliseconds > 604800000) {
        BiliValue.invalid();
      }
      segments.add(
        Mp4Segment(
          order: order,
          duration: Duration(milliseconds: milliseconds),
          size: BiliValue.count(row['size']),
          resource: _resource(row['url'], row['backup_url'], now),
        ),
      );
    }
    final total = segments.fold<int>(
      0,
      (sum, s) => sum + s.duration.inMilliseconds,
    );
    if ((total - length).abs() > 1000 * segments.length) BiliValue.invalid();
    return PlaybackSource(
      request: request,
      duration: duration,
      acquiredAt: now,
      returnedQuality: quality,
      mp4: segments,
    );
  }

  static List<DashTrack> _tracks(
    Object? raw,
    DashTrackKind kind,
    DateTime now, {
    DashAudioGroup group = DashAudioGroup.standard,
  }) {
    if (raw == null) return const [];
    if (raw is! List || raw.length > 200) BiliValue.invalid();
    final result = <DashTrack>[];
    final seen = <String>{};
    for (final entry in raw) {
      final row = BiliValue.map(entry);
      final id = BiliValue.integer(row['id']);
      final codec = BiliValue.text(row['codecs'], limit: 100, required: true);
      final codecId = BiliValue.integer(row['codecid']);
      final bandwidth = BiliValue.integer(row['bandwidth']);
      final mime = BiliValue.text(
        row['mime_type'] ?? row['mimeType'],
        limit: 100,
        required: true,
      );
      if (id <= 0 ||
          id > 100000 ||
          bandwidth <= 0 ||
          bandwidth > 1000000000 ||
          !RegExp(r'^[a-zA-Z0-9.\-]+$').hasMatch(codec) ||
          mime != (kind == DashTrackKind.video ? 'video/mp4' : 'audio/mp4') ||
          !seen.add('$id/$codec')) {
        BiliValue.invalid();
      }
      if (kind == DashTrackKind.video && ![7, 12, 13].contains(codecId)) {
        BiliValue.invalid();
      }
      final segment = BiliValue.map(row['segment_base'] ?? row['SegmentBase']);
      final init = _range(
        segment['initialization'] ?? segment['Initialization'],
      );
      final index = _range(segment['index_range'] ?? segment['indexRange']);
      if (init.start != 0 || index.start <= init.end) BiliValue.invalid();
      int? width, height;
      String? frame;
      if (kind == DashTrackKind.video) {
        width = BiliValue.integer(row['width']);
        height = BiliValue.integer(row['height']);
        if (width < 1 || height < 1 || width > 32768 || height > 32768) {
          BiliValue.invalid();
        }
        frame = BiliValue.text(
          row['frame_rate'] ?? row['frameRate'],
          limit: 30,
        );
        if (frame.isEmpty) frame = null;
        if (frame != null &&
            !RegExp(
              r'^[1-9]\d{0,5}(?:/[1-9]\d{0,5}|\.\d{1,5})?$',
            ).hasMatch(frame)) {
          BiliValue.invalid();
        }
      }
      result.add(
        DashTrack(
          kind: kind,
          id: id,
          codec: codec,
          codecId: codecId,
          mime: mime,
          bandwidth: bandwidth,
          resource: _resource(
            row['base_url'] ?? row['baseUrl'],
            row['backup_url'] ?? row['backupUrl'],
            now,
          ),
          initialization: init,
          indexRange: index,
          width: width,
          height: height,
          frameRate: frame,
          audioGroup: group,
        ),
      );
    }
    return result;
  }

  static SegmentRange _range(Object? raw) {
    if (raw is! String || !RegExp(r'^\d{1,16}-\d{1,16}$').hasMatch(raw)) {
      BiliValue.invalid();
    }
    final values = raw.split('-').map(int.parse).toList();
    if (values.first > values.last || values.last > 9007199254740991) {
      BiliValue.invalid();
    }
    return SegmentRange(values.first, values.last);
  }

  static MediaResource _resource(
    Object? primary,
    Object? backups,
    DateTime now,
  ) {
    if (backups != null && (backups is! List || backups.length > 20)) {
      BiliValue.invalid();
    }
    final locations = <Uri>[];
    var refresh = now.add(const Duration(minutes: 110));
    for (final value in [primary, ...backups as List? ?? const []]) {
      Uri uri;
      try {
        uri = BiliMediaPolicy.fromApi(value);
      } on ApiFailure {
        continue;
      }
      List<String>? deadlines;
      try {
        deadlines = uri.queryParametersAll['deadline'];
      } catch (_) {
        continue;
      }
      if (deadlines != null) {
        if (deadlines.length != 1 ||
            !RegExp(r'^\d{1,12}$').hasMatch(deadlines.single)) {
          continue;
        }
        final seconds = int.tryParse(deadlines.single);
        if (seconds == null || seconds > 253402300799) continue;
        final expiry = DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000,
          isUtc: true,
        ).subtract(const Duration(seconds: 30));
        if (!expiry.isAfter(now)) continue;
        if (expiry.isBefore(refresh)) refresh = expiry;
      }
      if (!locations.contains(uri)) locations.add(uri);
    }
    if (locations.isEmpty) {
      throw const ApiFailure(
        ApiFailureKind.unavailable,
        code: 'NO_USABLE_MEDIA_URL',
      );
    }
    return MediaResource(locations: locations, refreshAfter: refresh);
  }
}
