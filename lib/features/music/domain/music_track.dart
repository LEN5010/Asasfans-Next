import 'dart:math' as math;

class MusicTrack {
  const MusicTrack({
    required this.id,
    required this.date,
    required this.title,
    required this.members,
    required this.duration,
    required this.status,
  });
  final String id;
  final DateTime date;
  final String title;
  final List<String> members;
  final Duration duration;
  final String status;
  bool get isLive => status.toLowerCase().contains('live');
  String get singers => members.join('、');
  String get dateLabel =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  String get sessionKey => '$dateLabel/$singers';
}

String musicDuration(Duration value) =>
    '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';
double musicVolume(double gain) =>
    math.min(1.0, math.pow(10, gain / 20).toDouble());

/// The studio's search vocabulary changes when the group expands.
String musicSearchMembers(MusicTrack track) {
  final expanded = track.date.isAfter(DateTime(2023, 10, 15));
  final newer = track.members.contains('心宜') || track.members.contains('思诺');
  if (expanded &&
      track.members.length >= 5 &&
      track.members.contains('心宜') &&
      track.members.contains('思诺')) {
    return '枝江';
  }
  if (track.members.length >= 3 && (!expanded || !newer)) return 'A-SOUL';
  return track.members.join(' ');
}

Uri musicSearchLink(
  MusicTrack track, {
  required bool replay,
  required bool mobile,
  DateTime? now,
}) {
  var keyword = '${replay ? '直播录像' : track.title} ${musicSearchMembers(track)}';
  if (mobile) keyword += ' ${track.date.year}.${track.date.month}';
  final query = <String, String>{'keyword': keyword};
  if (!mobile) {
    // Calendar dates are from the studio's Beijing-time catalogue.
    final start = DateTime.utc(
      track.date.year,
      track.date.month,
      track.date.day,
    ).subtract(const Duration(hours: 8));
    final end = start.add(const Duration(days: 5));
    final current = (now ?? DateTime.now()).toUtc();
    query['pubtime_begin_s'] = '${start.millisecondsSinceEpoch ~/ 1000}';
    query['pubtime_end_s'] =
        '${(end.isBefore(current) ? end : current).millisecondsSinceEpoch ~/ 1000}';
    if (replay) query['duration'] = '4';
  }
  return Uri.https('search.bilibili.com', '/all', query);
}
