import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/core/storage/storage_failure.dart';
import 'package:asasfans_next/features/library/domain/library_models.dart';
import 'package:asasfans_next/features/updates/data/sqlite_update_repository.dart';
import 'package:asasfans_next/features/updates/domain/update_event.dart';
import 'package:asasfans_next/features/updates/domain/update_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_fixture.dart';

final _now = DateTime.utc(2026, 9, 22, 12);
final _calendar = Uri.https('asoul.love', '/calendar.ics');

UpdateEvent _video(int id, {DateTime? at, bool read = false}) {
  final content = ContentIdentity(
    source: ContentSource.bilibiliVideo,
    value: 'BV${id.toString().padLeft(10, '0')}',
  );
  return UpdateEvent(
    id: UpdateIds.subscriptionVideo(content),
    kind: UpdateKind.subscriptionVideo,
    title: '视频 $id',
    subtitle: 'UP 123',
    occurredAt: at ?? _now.subtract(Duration(minutes: id)),
    observedAt: _now,
    content: content,
    creator: const LocalSubscription(mid: '123', name: 'UP 123'),
    read: read,
  );
}

UpdateEvent _schedule(int sequence) {
  // A null recurrence id: the follow points at a standalone occurrence rather
  // than one instance of a repeating series.
  final followKey = CalendarFollowKey(
    source: _calendar,
    uid: 'e1',
    recurrenceId: null,
  );
  return UpdateEvent(
    id: UpdateIds.scheduleChange(followKey, sequence),
    kind: UpdateKind.scheduleChange,
    title: '直播',
    subtitle: '时间有变动',
    occurredAt: _now.add(const Duration(days: 3)),
    observedAt: _now,
    followKey: followKey,
    scheduleChange: ScheduleChange.rescheduled,
  );
}

UpdateHarvest _harvest(List<UpdateEvent> events, {UpdateCursor? cursor}) =>
    UpdateHarvest(
      events: events,
      cursors: cursor == null ? const {} : {cursor.sourceKey: cursor},
      failedSources: const {},
    );

void main() {
  late MemoryLocalDatabase db;
  late SqliteUpdateRepository repository;
  setUp(() {
    db = MemoryLocalDatabase();
    repository = SqliteUpdateRepository(db);
  });
  tearDown(() async {
    await repository.close();
    await db.close();
  });

  group('commit', () {
    test('events and their cursors land in one transaction', () async {
      await repository.commit(
        _harvest(
          [_video(1)],
          cursor: UpdateCursor(
            sourceKey: 'creator:123',
            baselineAt: _now,
            lastOccurredAt: _now,
            lastId: _video(1).id,
          ),
        ),
      );
      expect((await repository.counts()).unread, 1);
      expect((await repository.cursors())['creator:123']!.lastId, _video(1).id);
    });

    test('a rejected event leaves the cursor where it was', () async {
      await repository.commit(
        _harvest(
          const [],
          cursor: UpdateCursor(sourceKey: 'creator:123', baselineAt: _now),
        ),
      );
      // An event whose declared kind and payload disagree is refused before any
      // statement runs, so the batch never reaches the database.
      await expectLater(
        repository.commit(
          _harvest(
            [
              UpdateEvent(
                id: 'broken',
                kind: UpdateKind.subscriptionVideo,
                title: 'x',
                subtitle: 'y',
                occurredAt: _now,
                observedAt: _now,
              ),
            ],
            cursor: UpdateCursor(
              sourceKey: 'creator:123',
              baselineAt: _now,
              lastOccurredAt: _now,
              lastId: 'z',
            ),
          ),
        ),
        throwsA(isA<StorageFailure>()),
      );
      expect((await repository.cursors())['creator:123']!.lastId, isNull);
      expect((await repository.counts()).inbox, 0);
    });

    test('re-committing a read event does not resurrect it', () async {
      await repository.commit(_harvest([_video(1)]));
      await repository.markRead([_video(1).id], read: true);
      await repository.commit(_harvest([_video(1)]));
      final page = await repository.page(filter: UpdateFilter.inbox);
      expect(page.items.single.read, isTrue);
      expect((await repository.counts()).unread, 0);
    });

    test('re-committing refreshes the source-owned text only', () async {
      await repository.commit(_harvest([_video(1)]));
      await repository.archive([_video(1).id], archived: true);
      final renamed = UpdateEvent(
        id: _video(1).id,
        kind: UpdateKind.subscriptionVideo,
        title: '改名后的标题',
        subtitle: 'UP 123',
        occurredAt: _video(1).occurredAt,
        observedAt: _now.add(const Duration(days: 1)),
        content: _video(1).content,
      );
      await repository.commit(_harvest([renamed]));
      final page = await repository.page(filter: UpdateFilter.archived);
      expect(page.items.single.title, '改名后的标题');
      // Still archived, and observedAt still names the first sighting.
      expect(page.items.single.archived, isTrue);
      expect(page.items.single.observedAt, _now);
    });

    test('a cursor never moves backwards', () async {
      final ahead = UpdateCursor(
        sourceKey: 'creator:123',
        baselineAt: _now,
        lastOccurredAt: _now,
        lastId: 'zzz',
      );
      await repository.commit(_harvest(const [], cursor: ahead));
      await repository.commit(
        _harvest(
          const [],
          cursor: UpdateCursor(
            sourceKey: 'creator:123',
            baselineAt: _now,
            lastOccurredAt: _now.subtract(const Duration(days: 1)),
            lastId: 'aaa',
          ),
        ),
      );
      final stored = (await repository.cursors())['creator:123']!;
      expect(stored.lastOccurredAt, _now);
      expect(stored.lastId, 'zzz');
    });
  });

  group('reading', () {
    test(
      'the inbox is ordered by when things happened, not when polled',
      () async {
        final older = _video(1, at: _now.subtract(const Duration(days: 2)));
        final newer = _video(2, at: _now.subtract(const Duration(hours: 1)));
        // Committed oldest-last, so insertion order cannot be what orders it.
        await repository.commit(_harvest([newer]));
        await repository.commit(_harvest([older]));
        final page = await repository.page(filter: UpdateFilter.inbox);
        expect(page.items.map((e) => e.title), ['视频 2', '视频 1']);
      },
    );

    test('unread excludes read entries; archived excludes the inbox', () async {
      await repository.commit(_harvest([_video(1), _video(2), _video(3)]));
      await repository.markRead([_video(1).id], read: true);
      await repository.archive([_video(2).id], archived: true);
      expect(
        (await repository.page(
          filter: UpdateFilter.unread,
        )).items.map((e) => e.title),
        ['视频 3'],
      );
      expect(
        (await repository.page(
          filter: UpdateFilter.inbox,
        )).items.map((e) => e.title),
        ['视频 1', '视频 3'],
      );
      expect(
        (await repository.page(
          filter: UpdateFilter.archived,
        )).items.map((e) => e.title),
        ['视频 2'],
      );
      expect((await repository.counts()).unread, 1);
      expect((await repository.counts()).inbox, 2);
    });

    test('paging continues without repeating or skipping', () async {
      await repository.commit(
        _harvest([for (var id = 1; id <= 5; id++) _video(id)]),
      );
      final first = await repository.page(filter: UpdateFilter.inbox, limit: 2);
      expect(first.items, hasLength(2));
      final second = await repository.page(
        filter: UpdateFilter.inbox,
        cursor: first.next,
        limit: 2,
      );
      final third = await repository.page(
        filter: UpdateFilter.inbox,
        cursor: second.next,
        limit: 2,
      );
      final seen = [...first.items, ...second.items, ...third.items];
      expect(seen.map((e) => e.id).toSet(), hasLength(5));
      expect(third.next, isNull);
    });

    test(
      'a cursor from a changed store is refused rather than merged',
      () async {
        await repository.commit(
          _harvest([for (var id = 1; id <= 4; id++) _video(id)]),
        );
        final first = await repository.page(
          filter: UpdateFilter.inbox,
          limit: 2,
        );
        await repository.commit(_harvest([_video(9)]));
        await expectLater(
          repository.page(
            filter: UpdateFilter.inbox,
            cursor: first.next,
            limit: 2,
          ),
          throwsA(
            isA<StorageFailure>().having(
              (e) => e.kind,
              'kind',
              StorageFailureKind.changed,
            ),
          ),
        );
      },
    );

    test('a cursor from another filter is refused', () async {
      await repository.commit(
        _harvest([for (var id = 1; id <= 4; id++) _video(id)]),
      );
      final first = await repository.page(filter: UpdateFilter.inbox, limit: 2);
      await expectLater(
        repository.page(
          filter: UpdateFilter.unread,
          cursor: first.next,
          limit: 2,
        ),
        throwsA(
          isA<StorageFailure>().having(
            (e) => e.kind,
            'kind',
            StorageFailureKind.invalidData,
          ),
        ),
      );
    });
  });

  group('state', () {
    test('markAllRead leaves archived entries alone', () async {
      await repository.commit(_harvest([_video(1), _video(2)]));
      await repository.archive([_video(2).id], archived: true);
      await repository.markAllRead();
      expect((await repository.counts()).unread, 0);
      final archived = await repository.page(filter: UpdateFilter.archived);
      // Still unread, because the user already dealt with it another way.
      expect(archived.items.single.read, isFalse);
    });

    test(
      'unarchiving returns an entry to the inbox with its read state',
      () async {
        await repository.commit(_harvest([_video(1)]));
        await repository.markRead([_video(1).id], read: true);
        await repository.archive([_video(1).id], archived: true);
        await repository.archive([_video(1).id], archived: false);
        final page = await repository.page(filter: UpdateFilter.inbox);
        expect(page.items.single.read, isTrue);
        expect(page.items.single.archived, isFalse);
      },
    );

    test('a schedule entry round-trips its follow key and change', () async {
      await repository.commit(_harvest([_schedule(3)]));
      final stored = (await repository.page(
        filter: UpdateFilter.inbox,
      )).items.single;
      expect(stored.kind, UpdateKind.scheduleChange);
      expect(stored.scheduleChange, ScheduleChange.rescheduled);
      expect(stored.followKey!.source, _calendar);
      expect(stored.followKey!.uid, 'e1');
      // An absent recurrence id round-trips as absent, not as the empty string.
      expect(stored.followKey!.recurrenceId, isNull);
      expect(stored.content, isNull);
    });

    test('changes fire on commit and on state writes', () async {
      final seen = <int>[];
      final subscription = repository.changes.listen(seen.add);
      await repository.commit(_harvest([_video(1)]));
      await repository.markRead([_video(1).id], read: true);
      await repository.archive([_video(1).id], archived: true);
      await Future<void>.delayed(Duration.zero);
      expect(seen, hasLength(3));
      await subscription.cancel();
    });

    test(
      'an empty id list is a no-op rather than a full-table write',
      () async {
        await repository.commit(_harvest([_video(1)]));
        final seen = <int>[];
        final subscription = repository.changes.listen(seen.add);
        await repository.markRead(const [], read: true);
        await Future<void>.delayed(Duration.zero);
        expect(seen, isEmpty);
        expect((await repository.counts()).unread, 1);
        await subscription.cancel();
      },
    );
  });
}
