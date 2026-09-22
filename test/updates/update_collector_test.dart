import 'package:asasfans_next/core/domain/request_cancellation.dart';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/calendar/domain/calendar_event.dart';
import 'package:asasfans_next/features/library/domain/library_models.dart';
import 'package:asasfans_next/features/updates/application/update_collector.dart';
import 'package:asasfans_next/features/updates/domain/update_event.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/subscriptions_fixture.dart';

final _now = DateTime.utc(2026, 9, 22, 12);
final _source = Uri.https('asoul.love', '/calendar.ics');

UpdateCollector _collector(UpdateSource source) =>
    UpdateCollector(source, clock: () => _now);

List<LocalSubscription> _creators(List<String> mids) => [
  for (final mid in mids) LocalSubscription(mid: mid, name: 'UP $mid'),
];

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
  group('subscription baseline', () {
    test(
      'first sight of a creator reports nothing and records the point',
      () async {
        final source = UpdateSource()
          ..rows['123'] = [updateVideo(1), updateVideo(2), updateVideo(3)];
        final harvest = await _collector(
          source,
        ).collectSubscriptions(_creators(['123']), {});
        expect(harvest.events, isEmpty);
        expect(harvest.baselinedSources, {'creator:123'});
        final cursor = harvest.cursors['creator:123']!;
        // The newest item is where "new" starts, so the back catalogue below it
        // can never be reported later.
        expect(cursor.lastOccurredAt, updateVideo(1).publishedAt);
        expect(cursor.baselineAt, _now);
      },
    );

    test(
      'a creator with no dated items still baselines without events',
      () async {
        final source = UpdateSource()..rows['123'] = [];
        final harvest = await _collector(
          source,
        ).collectSubscriptions(_creators(['123']), {});
        expect(harvest.events, isEmpty);
        expect(harvest.cursors['creator:123']!.lastOccurredAt, isNull);
      },
    );

    test(
      'a second pass over unchanged source state produces nothing',
      () async {
        final source = UpdateSource()..rows['123'] = [updateVideo(1)];
        final collector = _collector(source);
        final first = await collector.collectSubscriptions(
          _creators(['123']),
          {},
        );
        final second = await collector.collectSubscriptions(
          _creators(['123']),
          first.cursors,
        );
        expect(second.events, isEmpty);
        expect(
          second.cursors['creator:123']!.lastOccurredAt,
          first.cursors['creator:123']!.lastOccurredAt,
        );
      },
    );
  });

  group('new videos', () {
    test('only items newer than the cursor become events', () async {
      final source = UpdateSource()..rows['123'] = [updateVideo(2)];
      final collector = _collector(source);
      final baseline = await collector.collectSubscriptions(
        _creators(['123']),
        {},
      );
      // updateVideo(1) is newer: its publish time is 100000-1 seconds.
      source.rows['123'] = [updateVideo(1), updateVideo(2)];
      final harvest = await collector.collectSubscriptions(
        _creators(['123']),
        baseline.cursors,
      );
      expect(harvest.events.map((e) => e.content!.value), [
        updateVideo(1).identity.value,
      ]);
      expect(harvest.events.single.creator!.mid, '123');
      expect(harvest.events.single.subtitle, 'UP 123');
    });

    test(
      'the id is derived from the video, so a repeat pass collides',
      () async {
        final source = UpdateSource()..rows['123'] = [updateVideo(5)];
        final collector = _collector(source);
        final baseline = await collector.collectSubscriptions(
          _creators(['123']),
          {},
        );
        source.rows['123'] = [updateVideo(4), updateVideo(5)];
        final first = await collector.collectSubscriptions(
          _creators(['123']),
          baseline.cursors,
        );
        // Re-running against the *old* cursor must produce the same id rather
        // than a new one, so the store can reject it as already present.
        final again = await collector.collectSubscriptions(
          _creators(['123']),
          baseline.cursors,
        );
        expect(first.events.single.id, again.events.single.id);
        expect(first.events.single.id, 'sub:bilibiliVideo:BV0000000004');
      },
    );

    test(
      'a burst is bounded but the cursor still passes the whole page',
      () async {
        final source = UpdateSource()..rows['123'] = [updateVideo(50)];
        final collector = _collector(source);
        final baseline = await collector.collectSubscriptions(
          _creators(['123']),
          {},
        );
        source.rows['123'] = [
          for (var id = 40; id <= 50; id++) updateVideo(id),
        ];
        final harvest = await collector.collectSubscriptions(
          _creators(['123']),
          baseline.cursors,
        );
        expect(harvest.events, hasLength(UpdateCollector.perCreatorLimit));
        // The newest of the burst is first; the cursor moved past all of them, so
        // the skipped middle is not offered again on the next pass.
        expect(harvest.events.first.content!.value, 'BV0000000040');
        final next = await collector.collectSubscriptions(
          _creators(['123']),
          harvest.cursors,
        );
        expect(next.events, isEmpty);
      },
    );
  });

  group('partial failure', () {
    test('one failing creator does not discard the others', () async {
      final source = UpdateSource()
        ..rows['123'] = [updateVideo(9)]
        ..rows['456'] = [updateVideo(9)];
      final collector = _collector(source);
      final baseline = await collector.collectSubscriptions(
        _creators(['123', '456']),
        {},
      );
      source.rows['123'] = [updateVideo(1), updateVideo(9)];
      source.failures['456'] = const ApiFailure(ApiFailureKind.timeout);
      final harvest = await collector.collectSubscriptions(
        _creators(['123', '456']),
        baseline.cursors,
      );
      expect(harvest.events, hasLength(1));
      expect(harvest.failedSources, {'creator:456'});
      expect(harvest.partial, isTrue);
      // The failed creator's cursor is absent, so the next pass retries from
      // the same point rather than skipping what it could not read.
      expect(harvest.cursors.containsKey('creator:456'), isFalse);
    });

    test(
      'cancellation aborts rather than reporting a partial success',
      () async {
        final source = UpdateSource()..rows['123'] = [updateVideo(1)];
        final cancellation = RequestCancellation()..cancel();
        expect(
          () => _collector(source).collectSubscriptions(
            _creators(['123']),
            {},
            cancellation: cancellation,
          ),
          throwsA(
            isA<ApiFailure>().having(
              (e) => e.kind,
              'kind',
              ApiFailureKind.cancelled,
            ),
          ),
        );
      },
    );
  });

  group('schedule changes', () {
    test('a higher sequence with a moved start is a reschedule', () {
      final followed = _event(sequence: 1);
      final harvest = _collector(UpdateSource()).collectSchedule(
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
      final harvest = _collector(UpdateSource()).collectSchedule(
        source: _source,
        follows: [_follow(_event(sequence: 1))],
        events: [_event(sequence: 2, status: EventStatus.cancelled)],
      );
      expect(harvest.events.single.scheduleChange, ScheduleChange.cancelled);
    });

    test('the same sequence is not a change', () {
      final harvest = _collector(UpdateSource()).collectSchedule(
        source: _source,
        follows: [_follow(_event(sequence: 2))],
        events: [_event(sequence: 2, start: DateTime.utc(2026, 10, 1, 20))],
      );
      expect(harvest.events, isEmpty);
    });

    test('absence from the snapshot is not cancellation', () {
      final harvest = _collector(UpdateSource()).collectSchedule(
        source: _source,
        follows: [_follow(_event(sequence: 1))],
        events: const [],
      );
      expect(harvest.events, isEmpty);
    });

    test('an occurrence moved earlier is still reported', () {
      final harvest = _collector(UpdateSource()).collectSchedule(
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
      final harvest = _collector(UpdateSource()).collectSchedule(
        source: _source,
        follows: [_follow(_event(sequence: 1))],
        events: [_event(sequence: 4, start: DateTime.utc(2026, 10, 2))],
      );
      expect(harvest.events.single.id, '["cal","$_source","e1",null,4]');
      // A different revision of the same occurrence is a different id, so the
      // store keeps them apart instead of silently overwriting.
      final later = _collector(UpdateSource()).collectSchedule(
        source: _source,
        follows: [_follow(_event(sequence: 1))],
        events: [_event(sequence: 5, start: DateTime.utc(2026, 10, 2))],
      );
      expect(later.events.single.id, isNot(harvest.events.single.id));
    });

    test('follows from another calendar source are ignored', () {
      final other = Uri.https('example.test', '/other.ics');
      final harvest = _collector(UpdateSource()).collectSchedule(
        source: other,
        follows: [_follow(_event(sequence: 1))],
        events: [_event(sequence: 2, start: DateTime.utc(2026, 10, 2))],
      );
      expect(harvest.events, isEmpty);
    });
  });
}
