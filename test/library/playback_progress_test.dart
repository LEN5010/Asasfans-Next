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

  test('absence of progress is null, not position zero', () async {
    expect(await repository.progress(_part('BV1', '77')), isNull);
  });

  test(
    'progress is stored per part and parts never overwrite each other',
    () async {
      final item = _item('BV1');
      await repository.saveProgress(
        item,
        '77',
        const Duration(seconds: 30),
        duration: const Duration(minutes: 10),
      );
      now = now.add(const Duration(minutes: 1));
      await repository.saveProgress(
        item,
        '88',
        const Duration(seconds: 90),
        duration: const Duration(minutes: 10),
      );

      final first = await repository.progress(_part('BV1', '77'));
      final second = await repository.progress(_part('BV1', '88'));
      expect(first!.position, const Duration(seconds: 30));
      expect(second!.position, const Duration(seconds: 90));

      final all = await repository.contentProgress(item.identity);
      expect(all.keys, {'77', '88'});
    },
  );

  test(
    'an unknown duration yields no fraction instead of a fake zero',
    () async {
      await repository.saveProgress(
        _item('BV1'),
        '77',
        const Duration(seconds: 5),
      );
      final progress = (await repository.progress(_part('BV1', '77')))!;
      expect(progress.durationKnown, isFalse);
      expect(progress.fraction, isNull);
      expect(progress.completed, isFalse);
    },
  );

  test(
    'a position inside the completion tail marks the part finished',
    () async {
      await repository.saveProgress(
        _item('BV1'),
        '77',
        const Duration(minutes: 9, seconds: 58),
        duration: const Duration(minutes: 10),
      );
      final progress = (await repository.progress(_part('BV1', '77')))!;
      expect(progress.completed, isTrue);
      // A finished part restarts rather than resuming two seconds from the end.
      expect(progress.resumePosition, Duration.zero);
    },
  );

  test('a position past a known duration is bounded to the duration', () async {
    await repository.saveProgress(
      _item('BV1'),
      '77',
      const Duration(minutes: 20),
      duration: const Duration(minutes: 10),
    );
    final progress = (await repository.progress(_part('BV1', '77')))!;
    expect(progress.position, const Duration(minutes: 10));
    expect(progress.fraction, 1.0);
  });

  test(
    'a later write wins and a known duration is not lost to an unknown one',
    () async {
      final item = _item('BV1');
      await repository.saveProgress(
        item,
        '77',
        const Duration(seconds: 10),
        duration: const Duration(minutes: 10),
      );
      now = now.add(const Duration(seconds: 30));
      // A subsequent report without a duration keeps the duration already known.
      await repository.saveProgress(item, '77', const Duration(seconds: 40));
      final progress = (await repository.progress(_part('BV1', '77')))!;
      expect(progress.position, const Duration(seconds: 40));
      expect(progress.duration, const Duration(minutes: 10));
    },
  );

  test('a stale write does not rewind a newer stored position', () async {
    final item = _item('BV1');
    now = DateTime.utc(2026, 9, 21, 5);
    await repository.saveProgress(item, '77', const Duration(seconds: 90));
    now = DateTime.utc(2026, 9, 21, 4); // a late callback from earlier
    await repository.saveProgress(item, '77', const Duration(seconds: 5));
    expect(
      (await repository.progress(_part('BV1', '77')))!.position,
      const Duration(seconds: 90),
    );
  });

  test(
    'progress keeps its snapshot alive after the item leaves every list',
    () async {
      final item = _item('BV1');
      await repository.setLater(item, true);
      await repository.saveProgress(item, '77', const Duration(seconds: 30));
      // Dropping watch-later prunes unreferenced content, but progress is a holder.
      await repository.setLater(item, false);
      final page = await repository.progressPage();
      expect(page.items.single.item.title, '视频 BV1');
      expect(page.items.single.progress.position, const Duration(seconds: 30));
    },
  );

  test('removing progress prunes a snapshot nothing else references', () async {
    final item = _item('BV1');
    await repository.saveProgress(item, '77', const Duration(seconds: 30));
    await repository.removeProgress(_part('BV1', '77'));
    expect((await repository.progressPage()).items, isEmpty);
    expect(
      db.database.select('SELECT * FROM content_refs'),
      isEmpty,
      reason: 'no asset references the snapshot anymore',
    );
  });

  test(
    'clearing progress leaves bookmarks, history and saved items intact',
    () async {
      final item = _item('BV1');
      await repository.setLater(item, true);
      await repository.recordHistory(item, HistoryAction.detail);
      await repository.addBookmark(item, '77', const Duration(seconds: 5));
      await repository.saveProgress(item, '77', const Duration(seconds: 30));

      await repository.clearProgress();
      expect((await repository.progressPage()).items, isEmpty);
      expect(await repository.bookmarks(_part('BV1', '77')), hasLength(1));
      expect(await repository.history(), hasLength(1));
      expect(await repository.later(), hasLength(1));
    },
  );

  test('the unfinished view hides completed parts', () async {
    final item = _item('BV1');
    await repository.saveProgress(
      item,
      '77',
      const Duration(minutes: 10),
      duration: const Duration(minutes: 10),
    );
    now = now.add(const Duration(minutes: 1));
    await repository.saveProgress(
      item,
      '88',
      const Duration(minutes: 1),
      duration: const Duration(minutes: 10),
    );
    expect((await repository.progressPage()).items, hasLength(1));
    expect(
      (await repository.progressPage(unfinishedOnly: false)).items,
      hasLength(2),
    );
  });

  test('an explicit completed flag overrides the inferred value', () async {
    final item = _item('BV1');
    await repository.saveProgress(
      item,
      '77',
      const Duration(seconds: 5),
      duration: const Duration(minutes: 10),
      completed: true,
    );
    expect((await repository.progress(_part('BV1', '77')))!.completed, isTrue);
  });

  test('a negative position is rejected as invalid data', () async {
    expect(
      () => repository.saveProgress(
        _item('BV1'),
        '77',
        const Duration(seconds: -1),
      ),
      throwsA(isA<StorageFailure>()),
    );
  });

  test(
    'an empty part id is rejected rather than stored as a blank key',
    () async {
      expect(
        () => repository.saveProgress(_item('BV1'), '  ', Duration.zero),
        throwsA(isA<StorageFailure>()),
      );
    },
  );
}
