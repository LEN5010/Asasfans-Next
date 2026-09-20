import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/core/storage/storage_failure.dart';
import 'package:asasfans_next/features/library/data/sqlite_library_repository.dart';
import 'package:asasfans_next/features/library/domain/library_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_fixture.dart';

ContentSnapshot _item(String id) => ContentSnapshot(
  identity: ContentIdentity(source: ContentSource.bilibiliVideo, value: id),
  title: '视频 $id',
  body: '简介 $id',
  authorName: '作者',
  authorId: '123',
  kind: LibraryMediaKind.video,
);

PlaybackPart _part(String id, String partId) => PlaybackPart(
  identity: ContentIdentity(source: ContentSource.bilibiliVideo, value: id),
  partId: partId,
);

void main() {
  late MemoryLocalDatabase db;
  late SqliteLibraryRepository repository;
  var now = DateTime.utc(2026, 9, 21, 4);
  setUp(() {
    now = DateTime.utc(2026, 9, 21, 4);
    db = MemoryLocalDatabase();
    repository = SqliteLibraryRepository(db, clock: () => now);
  });
  tearDown(() async {
    await repository.close();
    await db.close();
  });

  test(
    'a bookmark without an end is a point, not a zero-length range',
    () async {
      final item = _item('BV1');
      await repository.addBookmark(
        item,
        '77',
        const Duration(minutes: 1),
        title: '名场面',
      );
      final saved = (await repository.bookmarks(_part('BV1', '77'))).single;
      expect(saved.start, const Duration(minutes: 1));
      expect(saved.end, isNull);
      expect(saved.isRange, isFalse);
      expect(saved.length, isNull);
      expect(saved.title, '名场面');
    },
  );

  test('a range bookmark keeps its end and reports its length', () async {
    await repository.addBookmark(
      _item('BV1'),
      '77',
      const Duration(seconds: 30),
      end: const Duration(seconds: 90),
      title: '副歌',
    );
    final saved = (await repository.bookmarks(_part('BV1', '77'))).single;
    expect(saved.isRange, isTrue);
    expect(saved.length, const Duration(seconds: 60));
  });

  test('bookmarks are ordered by time within the part', () async {
    final item = _item('BV1');
    await repository.addBookmark(item, '77', const Duration(minutes: 5));
    await repository.addBookmark(item, '77', const Duration(minutes: 1));
    await repository.addBookmark(item, '77', const Duration(minutes: 3));
    expect(
      (await repository.bookmarks(
        _part('BV1', '77'),
      )).map((b) => b.start.inMinutes),
      [1, 3, 5],
    );
  });

  test('bookmarks are scoped to their own part', () async {
    final item = _item('BV1');
    await repository.addBookmark(item, '77', const Duration(minutes: 1));
    await repository.addBookmark(item, '88', const Duration(minutes: 2));
    expect(await repository.bookmarks(_part('BV1', '77')), hasLength(1));
    expect(await repository.bookmarks(_part('BV1', '88')), hasLength(1));
  });

  test('an end before the start is rejected', () async {
    expect(
      () => repository.addBookmark(
        _item('BV1'),
        '77',
        const Duration(seconds: 90),
        end: const Duration(seconds: 30),
      ),
      throwsA(isA<StorageFailure>()),
    );
  });

  test('updating a title and note leaves the time untouched', () async {
    final item = _item('BV1');
    final id = await repository.addBookmark(
      item,
      '77',
      const Duration(minutes: 2),
      title: '旧标题',
    );
    now = now.add(const Duration(minutes: 5));
    await repository.updateBookmark(id, title: '新标题', note: '备注');
    final saved = (await repository.bookmarks(_part('BV1', '77'))).single;
    expect(saved.title, '新标题');
    expect(saved.note, '备注');
    expect(saved.start, const Duration(minutes: 2));
    expect(saved.updatedAt.isAfter(saved.createdAt), isTrue);
  });

  test('clearEnd turns a range back into a point', () async {
    final id = await repository.addBookmark(
      _item('BV1'),
      '77',
      const Duration(seconds: 30),
      end: const Duration(seconds: 90),
    );
    await repository.updateBookmark(id, clearEnd: true);
    expect((await repository.bookmarks(_part('BV1', '77'))).single.end, isNull);
  });

  test('clearEnd together with an end is rejected as contradictory', () async {
    final id = await repository.addBookmark(
      _item('BV1'),
      '77',
      const Duration(seconds: 30),
    );
    expect(
      () => repository.updateBookmark(
        id,
        clearEnd: true,
        end: const Duration(seconds: 90),
      ),
      throwsA(isA<StorageFailure>()),
    );
  });

  test('an update that would invert an existing range is rejected', () async {
    final id = await repository.addBookmark(
      _item('BV1'),
      '77',
      const Duration(seconds: 30),
      end: const Duration(seconds: 90),
    );
    // Moving the start past the stored end must not leave an inverted range.
    expect(
      () => repository.updateBookmark(id, start: const Duration(seconds: 120)),
      throwsA(isA<StorageFailure>()),
    );
    expect(
      (await repository.bookmarks(_part('BV1', '77'))).single.start,
      const Duration(seconds: 30),
    );
  });

  test(
    'a bookmark keeps its snapshot alive after the item leaves every list',
    () async {
      final item = _item('BV1');
      await repository.setLater(item, true);
      await repository.addBookmark(
        item,
        '77',
        const Duration(minutes: 1),
        title: '记',
      );
      await repository.setLater(item, false);
      final page = await repository.bookmarkPage();
      expect(page.items.single.item.title, '视频 BV1');
      expect(page.items.single.bookmark.title, '记');
    },
  );

  test('removing the last bookmark prunes an unreferenced snapshot', () async {
    final item = _item('BV1');
    final id = await repository.addBookmark(item, '77', Duration.zero);
    await repository.removeBookmark(id);
    expect((await repository.bookmarkPage()).items, isEmpty);
    expect(db.database.select('SELECT * FROM content_refs'), isEmpty);
  });

  test('removing one bookmark keeps the others and the snapshot', () async {
    final item = _item('BV1');
    final first = await repository.addBookmark(item, '77', Duration.zero);
    await repository.addBookmark(item, '77', const Duration(minutes: 1));
    await repository.removeBookmark(first);
    expect(await repository.bookmarks(_part('BV1', '77')), hasLength(1));
    expect(db.database.select('SELECT * FROM content_refs'), hasLength(1));
  });

  test(
    'an update with no fields is a no-op rather than a bare timestamp write',
    () async {
      final item = _item('BV1');
      final id = await repository.addBookmark(item, '77', Duration.zero);
      final before = (await repository.bookmarks(_part('BV1', '77'))).single;
      now = now.add(const Duration(minutes: 5));
      await repository.updateBookmark(id);
      final after = (await repository.bookmarks(_part('BV1', '77'))).single;
      expect(after.updatedAt, before.updatedAt);
    },
  );

  test('an over-long note is rejected instead of being truncated', () async {
    expect(
      () => repository.addBookmark(
        _item('BV1'),
        '77',
        Duration.zero,
        note: 'x' * 2001,
      ),
      throwsA(isA<StorageFailure>()),
    );
  });
}
