import 'package:asasfans_next/features/player/domain/playback_source.dart';
import 'video_comment_fixture.dart';

const playbackRequest = PlaybackRequest(bvid: fixtureBvid, cid: '801');
final playbackNow = DateTime.utc(2026, 9, 21);
Map<String, Object?> dashTrack({
  int id = 80,
  bool audio = false,
  int? codecId,
}) => {
  'id': audio ? 30280 : id,
  'codecid': audio ? 0 : codecId ?? 7,
  'codecs': audio
      ? 'mp4a.40.2'
      : codecId == 12
      ? 'hev1.1.6.L120.90'
      : 'avc1.640028',
  'base_url':
      'https://primary.bilivideo.com/fixture.m4s?token=fixture-private&deadline=${playbackNow.add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000}',
  'backup_url': [
    'https://mirror.akamaized.net/fixture.m4s?token=fixture-mirror',
  ],
  'bandwidth': audio ? 192000 : 2000000,
  'mime_type': audio ? 'audio/mp4' : 'video/mp4',
  'segment_base': {'initialization': '0-99', 'index_range': '100-199'},
  if (!audio) ...{'width': 1920, 'height': 1080, 'frame_rate': '30000/1001'},
};
Map<String, Object?> dashPayload({bool silent = false}) => {
  'bvid': fixtureBvid,
  'cid': '801',
  'quality': 80,
  'timelength': 60000,
  'accept_quality': [120, 80, 64, 32],
  'dash': {
    'duration': 60,
    'video': [dashTrack(), dashTrack(id: 80, codecId: 12), dashTrack(id: 32)],
    'audio': silent ? null : [dashTrack(audio: true)],
  },
};
Map<String, Object?> mp4Payload({int segments = 1}) => {
  'quality': 32,
  'timelength': 30000 * segments,
  'format': 'mp4',
  'durl': [
    for (var i = 1; i <= segments; i++)
      {
        'order': i,
        'length': 30000,
        'size': 1000,
        'url':
            'https://primary.bilivideo.com/segment-$i.mp4?token=fixture-private',
        'backup_url': <String>[],
      },
  ],
};
