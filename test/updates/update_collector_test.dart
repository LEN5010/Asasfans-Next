import 'package:asasfans_next/features/calendar/domain/calendar_event.dart';
import 'package:asasfans_next/features/library/domain/library_models.dart';
import 'package:asasfans_next/features/updates/application/update_collector.dart';
import 'package:asasfans_next/features/updates/domain/update_event.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 9, 22, 12);
final _source = Uri.https('asoul.love', '/calendar.ics');

UpdateCollector _collector() => UpdateCollector(clock: () => _now);

CalendarEvent _event({
  String uid = 'e1',
  int sequence = 0,
  DateTime? start,
  EventStatus status = EventStatus.confirmed,
}) => CalendarEvent(
  uid: uid,
  title: '直播',
  start: start ?? DateTime.utc(2026, 10, 1, 12),
  end: (start ?? DateTime.utc(2026, 10, 1, 12)).add(const Duration(hours: 2)),
  allDay: false,
  sequence: sequence,
  status: status,
);

CalendarFollow _follow(CalendarEvent event) => CalendarFollow(
  key: CalendarFollowKey(
    source: _source,
    uid: event.uid,
    recurrenceId: event.recurrenceId,
  ),
  event: event,
  followedAt: _now,
);

void main() {
  group('schedule changes', () {
    test('a higher sequence with a moved start is a reschedule', () {
      final followed = _event(sequence: 1);
      final harvest = _collector().collectSchedule(
        source: _source,
        follows: [_follow(followed)],
        events: [_event(sequence: 2, start: DateTime.utc(2026, 10, 1, 20))],
      );
      expect(harvest.events.single.scheduleChange, ScheduleChange.rescheduled);
      expect(harvest.events.single.subtitle, '时间有变动');
      // The occurrence's own time orders it, not the moment it was noticed.
      expect(harvest.events.single.occurredAt, DateTime.utc(2026, 10, 1, 20));
    });

    test('a cancellation is reported as cancelled, not as a reschedule', () {
      final harvest = _collector().collectSchedule(
        source: _source,
        follows: [_follow(_event(sequence: 1))],
        events: [_event(sequence: 2, status: EventStatus.cancelled)],
      );
      expect(harvest.events.single.scheduleChange, ScheduleChange.cancelled);
    });

    test('the same sequence is not a change', () {
      final harvest = _collector().collectSchedule(
        source: _source,
        follows: [_follow(_event(sequence: 2))],
        events: [_event(sequence: 2, start: DateTime.utc(2026, 10, 1, 20))],
      );
      expect(harvest.events, isEmpty);
    });

    test('absence from the snapshot is not cancellation', () {
      final harvest = _collector().collectSchedule(
        source: _source,
        follows: [_follow(_event(sequence: 1))],
        events: const [],
      );
      expect(harvest.events, isEmpty);
    });

    test('an occurrence moved earlier is still reported', () {
      final harvest = _collector().collectSchedule(
        source: _source,
        follows: [_follow(_event(sequence: 1))],
        // A time cursor would have rejected this; the follow's sequence is the
        // real comparison point.
        events: [_event(sequence: 2, start: DateTime.utc(2026, 9, 25, 12))],
      );
      expect(harvest.events.single.scheduleChange, ScheduleChange.rescheduled);
      expect(harvest.events.single.occurredAt, DateTime.utc(2026, 9, 25, 12));
    });

    test('the event id carries the revision it was observed at', () {
      final harvest = _collector().collectSchedule(
        source: _source,
        follows: [_follow(_event(sequence: 1))],
        events: [_event(sequence: 4, start: DateTime.utc(2026, 10, 2))],
      );
      expect(harvest.events.single.id, '["cal","$_source","e1",null,4]');
      // A different revision of the same occurrence is a different id, so the
      // store keeps them apart instead of silently overwriting.
      final later = _collector().collectSchedule(
        source: _source,
        follows: [_follow(_event(sequence: 1))],
        events: [_event(sequence: 5, start: DateTime.utc(2026, 10, 2))],
      );
      expect(later.events.single.id, isNot(harvest.events.single.id));
    });

    test('follows from another calendar source are ignored', () {
      final other = Uri.https('example.test', '/other.ics');
      final harvest = _collector().collectSchedule(
        source: other,
        follows: [_follow(_event(sequence: 1))],
        events: [_event(sequence: 2, start: DateTime.utc(2026, 10, 2))],
      );
      expect(harvest.events, isEmpty);
    });
  });
}
