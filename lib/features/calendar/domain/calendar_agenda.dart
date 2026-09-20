import '../../../core/time/calendar_time.dart';
import 'calendar_event.dart';
import 'event_classifier.dart';

enum CalendarFilter {
  all('全部'),
  live('直播'),
  other('其他活动');

  const CalendarFilter(this.label);
  final String label;
}

abstract final class CalendarAgenda {
  static bool visible(
    CalendarEvent event, {
    CalendarFilter filter = CalendarFilter.all,
    Set<String> members = const {},
  }) {
    final kind = EventClassifier.classify(event);
    return (filter == CalendarFilter.all ||
            (filter == CalendarFilter.live
                ? kind == EventKind.live
                : kind == EventKind.other)) &&
        (members.isEmpty ||
            EventClassifier.members(event).any(members.contains));
  }

  static bool occursOn(CalendarEvent event, DateTime day) {
    if (!event.end.isAfter(event.start)) return false;
    final start = CalendarTime.dayOf(event.start, allDay: event.allDay);
    final last = CalendarTime.dayOf(
      event.end.subtract(const Duration(microseconds: 1)),
      allDay: event.allDay,
    );
    final date = CalendarTime.dayOf(day, allDay: true);
    return !date.isBefore(start) && !date.isAfter(last);
  }

  static List<CalendarEvent> onDay(
    Iterable<CalendarEvent> events,
    DateTime day,
  ) {
    final result = events.where((event) => occursOn(event, day)).toList();
    result.sort((a, b) {
      if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
      final start = a.start.compareTo(b.start);
      return start != 0 ? start : a.identity.compareTo(b.identity);
    });
    return List.unmodifiable(result);
  }

  /// Iterate the requested window, not every day of an untrusted long event.
  static Map<DateTime, List<CalendarEvent>> group(
    Iterable<CalendarEvent> events, {
    required DateTime from,
    required DateTime until,
  }) {
    final result = <DateTime, List<CalendarEvent>>{};
    for (
      var day = CalendarTime.dayOf(from, allDay: true);
      day.isBefore(until);
      day = day.add(const Duration(days: 1))
    ) {
      result[day] = onDay(events, day);
    }
    return result;
  }

  static DateTime weekStart(DateTime day) => CalendarTime.dayOf(
    day,
    allDay: true,
  ).subtract(Duration(days: day.weekday - 1));
  static String date(DateTime day) => '${day.month} 月 ${day.day} 日';
  static String time(DateTime instant) {
    final time = CalendarTime.inShanghai(instant);
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  static String range(CalendarEvent event) {
    final start = CalendarTime.dayOf(event.start, allDay: event.allDay);
    if (event.allDay) {
      final last = CalendarTime.dayOf(
        event.end.subtract(const Duration(days: 1)),
        allDay: true,
      );
      return '${start.year} 年 ${date(start)}${last == start ? '' : ' — ${last.year == start.year ? '' : '${last.year} 年 '}${date(last)}'} · 全天';
    }
    final end = CalendarTime.dayOf(event.end);
    return '${start.year} 年 ${date(start)} ${time(event.start)} — ${end == start ? '' : '${end.year == start.year ? '' : '${end.year} 年 '}${date(end)} '}${time(event.end)}';
  }
}
