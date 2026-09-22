import 'package:asasfans_next/features/calendar/domain/calendar_event.dart';
import 'package:asasfans_next/features/library/domain/library_models.dart';
import 'package:asasfans_next/features/reminders/domain/scheduled_reminder.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 9, 22, 12);
final _source = Uri.https('asoul.love', '/calendar.ics');

CalendarFollow _follow({
  String uid = 'e1',
  String? recurrenceId,
  DateTime? start,
  int sequence = 0,
  EventStatus status = EventStatus.confirmed,
  String title = '直播',
}) {
  final at = start ?? _now.add(const Duration(hours: 4));
  return CalendarFollow(
    key: CalendarFollowKey(
      source: _source,
      uid: uid,
      recurrenceId: recurrenceId,
    ),
    event: CalendarEvent(
      uid: uid,
      recurrenceId: recurrenceId,
      title: title,
      start: at,
      end: at.add(const Duration(hours: 2)),
      allDay: false,
      sequence: sequence,
      status: status,
    ),
    followedAt: _now,
  );
}

List<ScheduledReminder> _plan(
  List<CalendarFollow> follows, {
  ReminderLead lead = ReminderLead.fifteenMinutes,
}) => ReminderPlan.from(follows: follows, lead: lead, now: _now);

void main() {
  group('planning', () {
    test('a followed event gets one reminder at its lead time', () {
      final plan = _plan([_follow()]);
      expect(plan, hasLength(1));
      expect(
        plan.single.fireAt,
        _now
            .add(const Duration(hours: 4))
            .subtract(const Duration(minutes: 15)),
      );
    });

    test('turning reminders off plans nothing at all', () {
      expect(_plan([_follow()], lead: ReminderLead.none), isEmpty);
    });

    test('a cancelled occurrence is not planned', () {
      // The source called it off, so there is nothing to be reminded about.
      expect(_plan([_follow(status: EventStatus.cancelled)]), isEmpty);
    });

    test('an event whose lead time already passed is not fired late', () {
      // Starting in ten minutes with a fifteen-minute lead means the moment to
      // fire is gone. A late reminder for something already beginning is noise.
      final plan = _plan([
        _follow(start: _now.add(const Duration(minutes: 10))),
      ]);
      expect(plan, isEmpty);
    });

    test('a past event is not planned', () {
      expect(
        _plan([_follow(start: _now.subtract(const Duration(days: 1)))]),
        isEmpty,
      );
    });

    test('one occurrence yields one reminder even if followed twice', () {
      final plan = _plan([_follow(), _follow()]);
      expect(plan, hasLength(1));
    });

    test('occurrences of one series are distinct reminders', () {
      final plan = _plan([
        _follow(recurrenceId: '20261001'),
        _follow(
          recurrenceId: '20261002',
          start: _now.add(const Duration(days: 2)),
        ),
      ]);
      expect(plan, hasLength(2));
      // Two occurrences of the same uid must not collapse onto one id, or the
      // second would silently replace the first.
      expect(plan[0].id, isNot(plan[1].id));
    });

    test('the same occurrence always maps to the same id', () {
      expect(_plan([_follow()]).single.id, _plan([_follow()]).single.id);
    });
  });

  group('diffing', () {
    test('an unchanged reminder is left alone', () {
      final current = _plan([_follow()]);
      final diff = ReminderDiff.between(
        current: current,
        intended: _plan([_follow()]),
      );
      // An ordinary refresh must not churn every pending notification.
      expect(diff.isEmpty, isTrue);
    });

    test('a rescheduled event replaces its own reminder', () {
      final current = _plan([_follow()]);
      final moved = _plan([
        _follow(start: _now.add(const Duration(hours: 6)), sequence: 1),
      ]);
      final diff = ReminderDiff.between(current: current, intended: moved);
      expect(diff.schedule, hasLength(1));
      // Same id, so the platform replaces rather than adding a second
      // reminder for the same occurrence.
      expect(diff.schedule.single.id, current.single.id);
      expect(diff.cancel, isEmpty);
    });

    test('a cancelled event withdraws its reminder', () {
      final current = _plan([_follow()]);
      final diff = ReminderDiff.between(
        current: current,
        intended: _plan([_follow(status: EventStatus.cancelled, sequence: 1)]),
      );
      expect(diff.schedule, isEmpty);
      expect(diff.cancel, [current.single.id]);
    });

    test('unfollowing withdraws the reminder', () {
      final current = _plan([_follow()]);
      final diff = ReminderDiff.between(current: current, intended: const []);
      expect(diff.cancel, [current.single.id]);
    });

    test('turning reminders off withdraws everything', () {
      final current = _plan([_follow(), _follow(uid: 'e2')]);
      final diff = ReminderDiff.between(
        current: current,
        intended: _plan([
          _follow(),
          _follow(uid: 'e2'),
        ], lead: ReminderLead.none),
      );
      expect(diff.schedule, isEmpty);
      expect(diff.cancel, hasLength(2));
    });

    test('a renamed event updates its existing reminder', () {
      final current = _plan([_follow()]);
      final diff = ReminderDiff.between(
        current: current,
        intended: _plan([_follow(title: '改名后的直播', sequence: 1)]),
      );
      expect(diff.schedule.single.title, '改名后的直播');
      expect(diff.cancel, isEmpty);
    });
  });
}
