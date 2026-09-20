import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/core/storage/local_database.dart';
import 'package:asasfans_next/core/storage/storage_failure.dart';
import 'package:asasfans_next/features/calendar/domain/calendar_event.dart';
import 'package:asasfans_next/features/library/data/sqlite_library_repository.dart';
import 'package:asasfans_next/features/library/domain/library_models.dart';
import 'package:asasfans_next/features/library/domain/library_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_fixture.dart';

ContentSnapshot item(
  int id, [
  ContentSource source = ContentSource.bilibiliDynamic,
]) => ContentSnapshot(
  identity: ContentIdentity(source: source, value: '$id'),
  title: '内容 $id',
  body: '正文',
  authorName: 'UP',
);
Future<List<T>> drain<T>(
  Future<LibraryPage<T>> Function(LibraryCursor?) load,
) async {
  final result = <T>[];
  LibraryCursor? cursor;
  do {
    final page = await load(cursor);
    result.addAll(page.items);
    cursor = page.next;
    if (result.length > 1000) fail('cursor failed to advance');
  } while (cursor != null);
  return result;
}

Matcher failure(StorageFailureKind kind) =>
    throwsA(isA<StorageFailure>().having((e) => e.kind, 'kind', kind));

void main() {
  late MemoryLocalDatabase db;
  late SqliteLibraryRepository repo;
  setUp(() {
    db = MemoryLocalDatabase();
    repo = SqliteLibraryRepository(
      db,
      clock: () => DateTime.utc(2026),
      backgroundDecoding: false,
    );
  });
  tearDown(() async {
    await repo.close();
    await db.close();
  });

  test(
    'tied timestamps paginate every source and action once in stable order',
    () async {
      for (var i = 0; i < 47; i++) {
        for (final source in ContentSource.values) {
          final value = item(i, source);
          await repo.setCollected(value, 'default', true);
          await repo.setLater(value, true);
          if (i.isEven) await repo.setLaterDone(value.identity, true);
          for (final action in HistoryAction.values) {
            await repo.recordHistory(value, action);
          }
        }
      }
      for (final query in [
        const LibraryQuery.collection('default'),
        const LibraryQuery.later(),
        const LibraryQuery.later(pendingOnly: false),
        const LibraryQuery.history(),
        const LibraryQuery.history(action: HistoryAction.external),
      ]) {
        final paged = await drain(
          (cursor) => repo.recordPage(query, cursor: cursor, limit: 13),
        );
        final expected = switch (query.kind) {
          LibraryListKind.collection => await repo.collection('default'),
          LibraryListKind.later =>
            (await repo.later())
                .where((r) => !query.pendingOnly || !r.done)
                .toList(),
          LibraryListKind.history => await repo.history(action: query.action),
        };
        String key(LibraryRecord r) =>
            '${r.item.identity.source.name}/${r.item.identity.value}/${r.action?.name}';
        expect(paged.map(key), expected.map(key));
        expect(paged.map(key).toSet().length, paged.length);
      }
    },
  );
  test(
    'revision rejects delete/update across instances and keeps caches independent',
    () async {
      await repo.setLater(item(1), true);
      await repo.setLater(item(2), true);
      final first = await repo.recordPage(const LibraryQuery.later(), limit: 1);
      final other = SqliteLibraryRepository(db);
      addTearDown(other.close);
      await db.batch([
        const SqlStatement(
          "INSERT INTO preferences VALUES('appearance','dark')",
        ),
      ], write: true);
      expect(
        (await repo.recordPage(
          const LibraryQuery.later(),
          cursor: first.next,
        )).items,
        hasLength(1),
      );
      await other.setLaterDone(item(1).identity, true);
      await expectLater(
        repo.recordPage(const LibraryQuery.later(), cursor: first.next),
        failure(StorageFailureKind.changed),
      );
      final all = await repo.recordPage(
        const LibraryQuery.later(pendingOnly: false),
        limit: 1,
      );
      await other.setLater(item(2), false);
      await expectLater(
        repo.recordPage(
          const LibraryQuery.later(pendingOnly: false),
          cursor: all.next,
        ),
        failure(StorageFailureKind.changed),
      );
    },
  );
  test(
    'cursors are bound to store and query, limits and malformed keys are rejected',
    () async {
      await repo.setLater(item(1), true);
      await repo.setLater(item(2), true);
      final first = await repo.recordPage(const LibraryQuery.later(), limit: 1);
      await expectLater(
        repo.recordPage(const LibraryQuery.history(), cursor: first.next),
        failure(StorageFailureKind.invalidData),
      );
      await expectLater(
        repo.recordPage(
          const LibraryQuery.later(pendingOnly: false),
          cursor: first.next,
        ),
        failure(StorageFailureKind.invalidData),
      );
      final otherDb = MemoryLocalDatabase();
      final other = SqliteLibraryRepository(otherDb);
      addTearDown(() async {
        await other.close();
        await otherDb.close();
      });
      await expectLater(
        other.recordPage(const LibraryQuery.later(), cursor: first.next),
        failure(StorageFailureKind.changed),
      );
      for (final limit in [0, -1, 101]) {
        await expectLater(
          repo.recordPage(const LibraryQuery.later(), limit: limit),
          failure(StorageFailureKind.invalidData),
        );
      }
    },
  );
  test(
    'folder, subscription and calendar lists continue by compound identities',
    () async {
      final event = CalendarEvent(
        uid: 'same',
        title: '日程',
        start: DateTime.utc(2026),
        end: DateTime.utc(2026, 1, 1, 1),
        allDay: false,
      );
      for (var i = 1; i <= 7; i++) {
        await repo.createFolder('目录 $i');
        await repo.subscribe(LocalSubscription(mid: '$i', name: 'UP $i'));
        await repo.followCalendar(
          CalendarFollowKey(
            source: Uri.https('source$i.example', '/calendar.ics'),
            uid: event.uid,
          ),
          event,
        );
      }
      expect(
        await drain((cursor) => repo.folderPage(cursor: cursor, limit: 2)),
        hasLength(8),
      );
      expect(
        await drain(
          (cursor) => repo.subscriptionPage(cursor: cursor, limit: 2),
        ),
        hasLength(7),
      );
      expect(
        await drain(
          (cursor) => repo.calendarFollowPage(cursor: cursor, limit: 2),
        ),
        hasLength(7),
      );
      expect(await repo.isSubscribed('7'), isTrue);
      expect(await repo.isSubscribed('8'), isFalse);
      expect(await repo.folder('missing'), isNull);
    },
  );
  test(
    'production page decoders can cross an isolate without repository captures',
    () async {
      final isolated = SqliteLibraryRepository(db);
      addTearDown(isolated.close);
      await isolated.setLater(item(1), true);
      expect(
        (await isolated.recordPage(
          const LibraryQuery.later(),
        )).items.single.item.body,
        '正文',
      );
      expect((await isolated.folderPage()).items.single.id, 'default');
      await isolated.subscribe(const LocalSubscription(mid: '1', name: 'UP'));
      expect((await isolated.subscriptionPage()).items.single.mid, '1');
    },
  );
}
