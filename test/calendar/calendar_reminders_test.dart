import 'package:flutter_test/flutter_test.dart';
import 'package:asasfans_next/features/calendar/application/calendar_follow_selection.dart';
import 'package:asasfans_next/features/calendar/application/calendar_reminders.dart';
import 'package:asasfans_next/features/calendar/domain/calendar_event.dart';
import 'package:asasfans_next/features/library/domain/library_models.dart';

void main() {
  final calendar = Uri.parse('https://asoul.love/calendar.ics');
  final now = DateTime.utc(2026, 10, 16, 10);
  CalendarEvent event(
    String uid, {
    String title = '嘉然直播',
    int minutes = 60,
    bool allDay = false,
    EventStatus status = EventStatus.confirmed,
  }) => CalendarEvent(
    uid: uid,
    title: title,
    start: now.add(Duration(minutes: minutes)),
    end: now.add(Duration(minutes: minutes + 120)),
    allDay: allDay,
    status: status,
  );
  CalendarFollow star(CalendarEvent event) => CalendarFollow(
    key: CalendarFollowKey(source: calendar, uid: event.uid),
    event: event,
    followedAt: now,
  );

  test(
    'member subscriptions and individual stars form a union, excluding cancelled and non-live events',
    () {
      final diana = event('diana');
      final eileen = event('eileen', title: '乃琳直播');
      final bella = event('bella', title: '贝拉直播');
      final cancelled = event('cancelled', status: EventStatus.cancelled);
      final birthday = event('birthday', title: '嘉然生日', allDay: true);
      final result = calendarReminderPlan(
        events: [diana, eileen, bella, cancelled, birthday],
        calendar: calendar,
        selection: CalendarFollowSelection(
          members: {'嘉然'},
          stars: [star(eileen), star(diana)],
        ),
        now: now,
        minutes: 5,
      );
      expect(result.map((item) => item.event.uid), ['diana', 'eileen']);
      expect(result.first.record.fireAt, now.add(const Duration(minutes: 55)));
    },
  );

  test(
    'elapsed reminder windows are never rescheduled and dates beyond thirty days are excluded',
    () {
      final result = calendarReminderPlan(
        events: [
          event('started', minutes: -1),
          event('elapsed', minutes: 3),
          event('future'),
          event('far', minutes: 31 * 24 * 60),
        ],
        calendar: calendar,
        selection: const CalendarFollowSelection(members: {'嘉然'}, stars: []),
        now: now,
        minutes: 5,
      );
      expect(result.map((item) => item.event.uid), ['future']);
    },
  );

  test(
    'a reschedule or title edit changes the OS notification id, refresh alone keeps it stable',
    () {
      final original = event('one');
      final selection = const CalendarFollowSelection(
        members: {'嘉然'},
        stars: [],
      );
      int id(CalendarEvent value, DateTime clock) => calendarReminderPlan(
        events: [value],
        calendar: calendar,
        selection: selection,
        now: clock,
        minutes: 5,
      ).single.record.notificationId;
      expect(
        id(original, now),
        id(original, now.add(const Duration(minutes: 1))),
      );
      expect(
        id(original, now),
        isNot(
          id(
            original.copyWith(
              start: original.start.add(const Duration(hours: 1)),
            ),
            now,
          ),
        ),
      );
      expect(
        id(original, now),
        isNot(id(event('one', title: '嘉然直播：新标题'), now)),
      );
    },
  );

  test('keeps the nearest fifty reminders in stable chronological order', () {
    final result = calendarReminderPlan(
      events: [for (var i = 60; i > 0; i--) event('$i', minutes: i * 10)],
      calendar: calendar,
      selection: const CalendarFollowSelection(members: {'嘉然'}, stars: []),
      now: now,
      minutes: 5,
    );
    expect(result, hasLength(50));
    expect(result.first.event.uid, '1');
    expect(result.last.event.uid, '50');
    expect(
      result.map((item) => item.record.notificationId).toSet(),
      hasLength(50),
    );
  });
}
