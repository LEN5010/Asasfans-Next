import 'calendar_event.dart';

/// Classifies events for display only.
///
/// The bot drops non-livestreams at the source. The app keeps every event and
/// applies these rules at presentation time, so birthdays and anniversaries
/// stay in the model and remain visible under "all".
abstract final class EventClassifier {
  static const liveKeywords = {
    '直播',
    '开播',
    'live',
    '突击',
    '2d',
    '节目',
    '综艺',
    '线下',
    '歌会',
    '歌杂',
    '杂谈',
    '电台',
    '联动',
    '游戏',
    '演唱会',
    'birthday live',
    'sing',
  };

  static const nonLiveKeywords = {'投稿', '翻唱发布', '周边', '纪念', '生日', '周年', '首发'};

  static const memberAliases = <String, List<String>>{
    '向晚': ['向晚', 'ava'],
    '贝拉': ['贝拉', 'bella'],
    '珈乐': ['珈乐', 'carol'],
    '嘉然': ['嘉然', 'diana'],
    '乃琳': ['乃琳', 'eileen'],
    '心宜': ['心宜', 'fiona'],
    '思诺': ['思诺', 'gladys'],
    'A-SOUL': ['a-soul', 'asoul', '一个魂'],
  };

  /// A scheduled programme entry, not a report of a live channel's real state.
  static EventKind classify(CalendarEvent event) {
    if (event.isCancelled || event.allDay) return EventKind.other;
    if (event.sourceUrl?.host.toLowerCase().contains('live.bilibili.com') ??
        false) {
      return EventKind.live;
    }
    final text = [
      event.title,
      event.location,
      ...event.categories,
    ].join(' ').toLowerCase();
    if (liveKeywords.any(text.contains)) return EventKind.live;
    if (nonLiveKeywords.any(text.contains)) return EventKind.other;
    // An unlabelled timed entry on this calendar is a broadcast by default.
    return EventKind.live;
  }

  /// Members named anywhere in the event text, in a stable order.
  static List<String> members(CalendarEvent event) {
    final text = [
      event.title,
      event.location,
      event.description,
      ...event.categories,
    ].join(' ').toLowerCase();
    return List.unmodifiable(
      memberAliases.entries
          .where((entry) => entry.value.any(text.contains))
          .map((entry) => entry.key),
    );
  }
}
