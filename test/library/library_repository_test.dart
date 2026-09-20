import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/core/storage/storage_failure.dart';
import 'package:asasfans_next/features/calendar/domain/calendar_event.dart';
import 'package:asasfans_next/features/library/data/sqlite_library_repository.dart';
import 'package:asasfans_next/features/library/domain/library_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_fixture.dart';

ContentSnapshot _item(
  String id, {
  ContentSource source = ContentSource.bilibiliDynamic,
}) => ContentSnapshot(
  identity: ContentIdentity(source: source, value: id),
  title: '作品 $id',
  body: '全文 $id',
  authorName: '作者',
  authorId: '123',
);
CalendarEvent _event(
  String uid, {
  String? recurrence,
  int sequence = 0,
  EventStatus status = EventStatus.confirmed,
  int day = 21,
}) => CalendarEvent(
  uid: uid,
  recurrenceId: recurrence,
  sequence: sequence,
  title: '日程 $uid',
  start: DateTime.utc(2026, 9, day, 12),
  end: DateTime.utc(2026, 9, day, 14),
  allDay: false,
  status: status,
  members: const ['嘉然'],
  description: '日程简介',
);

void main() {
  late MemoryLocalDatabase db;
  late SqliteLibraryRepository repository;
  setUp(() {
    db = MemoryLocalDatabase();
    repository = SqliteLibraryRepository(
      db,
      clock: () => DateTime.utc(2026, 9, 21, 4),
    );
  });
  tearDown(() async {
    await repository.close();
    await db.close();
  });

  test(
    'one reference may belong to several folders; removing one preserves other assets',
    () async {
      final item = _item('100000000000000000001');
      final second = await repository.createFolder('画作');
      await repository.setCollected(item, 'default', true);
      await repository.setCollected(item, second, true);
      await repository.setLater(item, true);
      await repository.recordHistory(item, HistoryAction.detail);
      expect((await repository.itemState(item.identity)).folderIds, {
        'default',
        second,
      });
      await repository.deleteFolder(second);
      expect(
        (await repository.collection('default')).single.item.identity,
        item.identity,
      );
      expect(await repository.later(), hasLength(1));
      await repository.clearHistory();
      expect(await repository.history(), isEmpty);
      expect(await repository.collection('default'), hasLength(1));
      await repository.setCollected(item, 'default', false);
      expect(await repository.later(), hasLength(1));
      await repository.setLater(item, false);
      expect(db.database.select('SELECT * FROM content_refs'), isEmpty);
    },
  );

  test(
    'source namespaces never collide and duplicate saves do not multiply rows',
    () async {
      final bili = _item('same');
      final douban = _item('same', source: ContentSource.doubanTopic);
      await repository.setCollected(bili, 'default', true);
      await repository.setCollected(douban, 'default', true);
      await repository.setCollected(bili, 'default', true);
      expect(await repository.collection('default'), hasLength(2));
      expect((await repository.folders()).single.count, 2);
      await repository.setCollected(bili, 'default', false);
      expect(
        (await repository.collection('default')).single.item.identity.source,
        ContentSource.doubanTopic,
      );
    },
  );

  test(
    'missing-folder failure rolls back its new content reference and emits no revision',
    () async {
      final revisions = <int>[];
      final subscription = repository.changes.listen(revisions.add);
      await expectLater(
        repository.setCollected(_item('broken'), 'missing', true),
        throwsA(isA<StorageFailure>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(revisions, isEmpty);
      expect(db.database.select('SELECT * FROM content_refs'), isEmpty);
      await repository.setCollected(_item('good'), 'default', true);
      await Future<void>.delayed(Duration.zero);
      expect(revisions, hasLength(1));
      await subscription.cancel();
    },
  );

  test(
    'detail, external open and playback histories are separate from later completion',
    () async {
      final item = _item('history');
      await repository.recordHistory(item, HistoryAction.detail);
      await repository.recordHistory(item, HistoryAction.detail);
      await repository.recordHistory(item, HistoryAction.external);
      await repository.setLater(item, true);
      await repository.setLaterDone(item.identity, true);
      expect(await repository.history(action: HistoryAction.playback), isEmpty);
      expect(
        (await repository.history(action: HistoryAction.detail)).single.visits,
        2,
      );
      expect((await repository.later()).single.done, isTrue);
      await repository.recordHistory(item, HistoryAction.playback);
      await repository.clearHistory(action: HistoryAction.detail);
      expect(await repository.history(), hasLength(2));
      expect(await repository.later(), hasLength(1));
      await repository.removeHistory(item.identity, HistoryAction.external);
      expect(
        (await repository.history()).single.action,
        HistoryAction.playback,
      );
    },
  );

  test(
    'subscriptions are idempotent local relations and reject malformed MIDs',
    () async {
      await repository.subscribe(
        const LocalSubscription(mid: '123', name: '原名'),
      );
      await repository.subscribe(
        const LocalSubscription(mid: '123', name: '新名'),
      );
      expect((await repository.subscriptions()).single.name, '新名');
      expect(
        () => repository.subscribe(
          const LocalSubscription(mid: 'https://example.com', name: 'wrong'),
        ),
        throwsA(isA<StorageFailure>()),
      );
      await repository.unsubscribe('123');
      expect(await repository.subscriptions(), isEmpty);
    },
  );

  test(
    'calendar tuple identity survives collisions, source differences and rescheduling',
    () async {
      final source = Uri.parse('https://one.example/calendar.ics');
      final otherSource = Uri.parse('https://two.example/calendar.ics');
      final first = _event('a/b');
      final second = _event('a', recurrence: 'b');
      expect(
        first.identity,
        isNot(second.identity),
      ); // Tuple encoding is unambiguous.
      final key = CalendarFollowKey(source: source, uid: first.uid);
      await repository.followCalendar(key, first);
      await repository.followCalendar(
        CalendarFollowKey(source: source, uid: second.uid, recurrenceId: 'b'),
        second,
      );
      await repository.followCalendar(
        CalendarFollowKey(source: otherSource, uid: first.uid),
        first,
      );
      await repository.synchronizeCalendar(source, [
        _event('a/b', sequence: 1, day: 25),
      ], DateTime.utc(2026, 9, 22));
      final follows = await repository.calendarFollows();
      expect(follows, hasLength(3));
      expect(
        follows.singleWhere((entry) => entry.key == key).event.start.day,
        25,
      );
      expect(
        follows
            .singleWhere((entry) => entry.key.source == otherSource)
            .event
            .start
            .day,
        21,
      );
      // Not present in a new feed is not confirmed cancellation or deletion.
      expect(
        follows
            .singleWhere((entry) => entry.key.recurrenceId == 'b')
            .event
            .isCancelled,
        isFalse,
      );
      await repository.synchronizeCalendar(source, [
        _event('a/b', sequence: 2, status: EventStatus.cancelled, day: 25),
      ], DateTime.utc(2026, 9, 23));
      await repository.synchronizeCalendar(source, [
        _event('a/b', sequence: 1, day: 20),
      ], DateTime.utc(2026, 9, 24));
      expect(
        (await repository.calendarFollows())
            .singleWhere((entry) => entry.key == key)
            .event
            .isCancelled,
        isTrue,
      );
      await repository.unfollowCalendar(key);
      expect(await repository.calendarFollows(), hasLength(2));
    },
  );

  test(
    'closed repositories reject new work and default folder cannot be removed',
    () async {
      await expectLater(
        repository.deleteFolder('default'),
        throwsA(isA<StorageFailure>()),
      );
      expect((await repository.folders()).single.isDefault, isTrue);
      await repository.close();
      await expectLater(
        repository.folders(),
        throwsA(
          isA<StorageFailure>().having(
            (error) => error.kind,
            'kind',
            StorageFailureKind.closed,
          ),
        ),
      );
    },
  );
}
