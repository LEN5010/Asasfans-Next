import 'package:asasfans_next/features/calendar/domain/calendar_agenda.dart';
import 'package:asasfans_next/features/calendar/domain/calendar_event.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarEvent event(
  String uid,
  DateTime start,
  DateTime end, {
  bool allDay = false,
  List<String> members = const [],
}) => CalendarEvent(
  uid: uid,
  title: '安排',
  start: start,
  end: end,
  allDay: allDay,
  members: members,
);

void main() {
  test('timed events use Shanghai dates and exclude the ending midnight', () {
    final e = event(
      'overnight',
      DateTime.utc(2026, 9, 21, 15),
      DateTime.utc(2026, 9, 22, 16),
    );
    expect(CalendarAgenda.occursOn(e, DateTime.utc(2026, 9, 21)), isTrue);
    expect(CalendarAgenda.occursOn(e, DateTime.utc(2026, 9, 22)), isTrue);
    expect(CalendarAgenda.occursOn(e, DateTime.utc(2026, 9, 23)), isFalse);
    expect(CalendarAgenda.range(e), '2026 年 9 月 21 日 23:00 — 9 月 23 日 00:00');
  });

  test('all-day dates remain pure dates with an exclusive end', () {
    final e = event(
      'holiday',
      DateTime.utc(2026, 12, 31),
      DateTime.utc(2027, 1, 2),
      allDay: true,
    );
    expect(CalendarAgenda.occursOn(e, DateTime.utc(2027, 1, 1)), isTrue);
    expect(CalendarAgenda.occursOn(e, DateTime.utc(2027, 1, 2)), isFalse);
    expect(CalendarAgenda.range(e), '2026 年 12 月 31 日 — 2027 年 1 月 1 日 · 全天');
    expect(
      CalendarAgenda.range(
        event(
          'single',
          DateTime.utc(2026, 9, 21),
          DateTime.utc(2026, 9, 22),
          allDay: true,
        ),
      ),
      '2026 年 9 月 21 日 · 全天',
    );
  });

  test('one week groups both months and bounds even a multi-century event', () {
    final from = CalendarAgenda.weekStart(DateTime.utc(2026, 10, 1));
    expect(from, DateTime.utc(2026, 9, 28));
    final e = event(
      'long',
      DateTime.utc(1900),
      DateTime.utc(2200),
      allDay: true,
    );
    final grouped = CalendarAgenda.group(
      [e],
      from: from,
      until: from.add(const Duration(days: 7)),
    );
    expect(grouped, hasLength(7));
    expect(grouped.keys.last, DateTime.utc(2026, 10, 4));
    expect(grouped.values.every((events) => events.single == e), isTrue);
    expect(CalendarAgenda.group([e], from: from, until: from), isEmpty);
  });

  test('all-day entries precede timed events and ties have a stable order', () {
    final day = DateTime.utc(2026, 9, 21);
    final timed = day.add(const Duration(hours: 4));
    final a = event('a', timed, timed.add(const Duration(hours: 1)));
    final b = event('b', timed, timed.add(const Duration(hours: 1)));
    final all = event(
      'all',
      day,
      day.add(const Duration(days: 1)),
      allDay: true,
    );
    final empty = event('empty', timed, timed);
    expect(CalendarAgenda.onDay([b, a, all, empty], day), [all, a, b]);
  });

  test('members are OR alternatives while the type remains an AND filter', () {
    final e = event(
      'members',
      DateTime.utc(2026, 9, 21),
      DateTime.utc(2026, 9, 22),
      allDay: true,
      members: ['Diana'],
    );
    expect(CalendarAgenda.visible(e, members: {'嘉然', '贝拉'}), isTrue);
    expect(CalendarAgenda.visible(e, members: {'贝拉'}), isFalse);
    expect(
      CalendarAgenda.visible(e, filter: CalendarFilter.live, members: {'嘉然'}),
      isFalse,
    );
    expect(
      CalendarAgenda.visible(e, filter: CalendarFilter.other, members: {'嘉然'}),
      isTrue,
    );
  });
}
