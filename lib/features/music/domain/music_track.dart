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
  bool get hasMoreMembers => members.any(const {'向晚', '珈乐'}.contains);
  bool get isLive => status.toLowerCase().contains('live');
  String get singers => members.join('、');
  String get dateLabel =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}

/// One day's 歌回, songs in catalogue order. A group stream has songs sung
/// by different sets of members, so the day, not the singers, is the unit.
class MusicSession {
  const MusicSession(this.date, this.tracks);
  final DateTime date;
  final List<MusicTrack> tracks;

  /// Everyone who sang that day, in the order they first appear.
  List<String> get members => [
    ...{for (final track in tracks) ...track.members},
  ];
}

/// [tracks] grouped by day, newest day first or, with [oldest], oldest
/// first; within a day the catalogue's own order is kept.
List<MusicSession> musicSessions(
  Iterable<MusicTrack> tracks, {
  bool oldest = false,
}) {
  final days = <DateTime, List<MusicTrack>>{};
  for (final track in tracks) {
    days.putIfAbsent(track.date, () => []).add(track);
  }
  final sessions =
      [
        for (final MapEntry(:key, :value) in days.entries)
          MusicSession(key, value),
      ]..sort(
        (a, b) => oldest ? a.date.compareTo(b.date) : b.date.compareTo(a.date),
      );
  return sessions;
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
