import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/core/storage/storage_failure.dart';
import 'package:asasfans_next/features/library/application/progress_recorder.dart';
import 'package:asasfans_next/features/library/data/sqlite_library_repository.dart';
import 'package:asasfans_next/features/library/domain/library_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_fixture.dart';

ContentSnapshot _item(String id) => ContentSnapshot(
  identity: ContentIdentity(source: ContentSource.bilibiliVideo, value: id),
  title: '视频 $id',
  body: '简介',
  authorName: '作者',
  authorId: '123',
  kind: LibraryMediaKind.video,
);

PlaybackPart _part(String id, String partId) => PlaybackPart(
  identity: ContentIdentity(source: ContentSource.bilibiliVideo, value: id),
  partId: partId,
);

/// Counts writes so a test can prove reports were merged rather than stored one
/// by one.
class _CountingRepository extends SqliteLibraryRepository {
  _CountingRepository(super.db, {super.clock});
  int writes = 0;
  Object? failWith;

  @override
  Future<void> saveProgress(
    ContentSnapshot item,
    String partId,
    Duration position, {
    Duration duration = Duration.zero,
    bool? completed,
  }) {
    writes++;
    if (failWith != null) return Future.error(failWith!);
    return super.saveProgress(
      item,
      partId,
      position,
      duration: duration,
      completed: completed,
    );
  }
}

void main() {
  late MemoryLocalDatabase db;
  late _CountingRepository repository;
  setUp(() {
    db = MemoryLocalDatabase();
    repository = _CountingRepository(
      db,
      clock: () => DateTime.utc(2026, 9, 21, 4),
    );
  });
  tearDown(() async {
    await repository.close();
    await db.close();
  });

  test('many reports for one part collapse into a single write', () async {
    final recorder = ProgressRecorder(repository);
    final item = _item('BV1');
    for (var second = 1; second <= 50; second++) {
      recorder.record(item, '77', Duration(seconds: second));
    }
    await recorder.flush();
    expect(repository.writes, 1);
    // The surviving position is the newest one, not the first or an average.
    expect(
      (await repository.progress(_part('BV1', '77')))!.position,
      const Duration(seconds: 50),
    );
  });

  test('reports for different parts are each written once', () async {
    final recorder = ProgressRecorder(repository);
    final item = _item('BV1');
    recorder.record(item, '77', const Duration(seconds: 10));
    recorder.record(item, '88', const Duration(seconds: 20));
    recorder.record(item, '77', const Duration(seconds: 30));
    await recorder.flush();
    expect(repository.writes, 2);
    expect(
      (await repository.progress(_part('BV1', '77')))!.position,
      const Duration(seconds: 30),
    );
    expect(
      (await repository.progress(_part('BV1', '88')))!.position,
      const Duration(seconds: 20),
    );
  });

  test('nothing is written without a report', () async {
    final recorder = ProgressRecorder(repository);
    await recorder.flush();
    expect(repository.writes, 0);
  });

  test(
    'a completed report is written without waiting for the interval',
    () async {
      final recorder = ProgressRecorder(
        repository,
        interval: const Duration(minutes: 10),
      );
      recorder.record(
        _item('BV1'),
        '77',
        const Duration(minutes: 10),
        duration: const Duration(minutes: 10),
        completed: true,
      );
      // No flush() call and no interval wait: completion is written promptly.
      await Future<void>.delayed(Duration.zero);
      await recorder.flush();
      expect(
        (await repository.progress(_part('BV1', '77')))!.completed,
        isTrue,
      );
    },
  );

  test('the interval timer writes without an explicit flush', () async {
    final recorder = ProgressRecorder(
      repository,
      interval: const Duration(milliseconds: 20),
    );
    addTearDown(recorder.close);
    recorder.record(_item('BV1'), '77', const Duration(seconds: 3));
    expect(repository.writes, 0, reason: 'a report alone does not write');
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(repository.writes, 1);
    expect(
      (await repository.progress(_part('BV1', '77')))!.position,
      const Duration(seconds: 3),
    );
  });

  test('a failed write does not throw into the player', () async {
    final recorder = ProgressRecorder(repository);
    repository.failWith = const StorageFailure(StorageFailureKind.unavailable);
    recorder.record(_item('BV1'), '77', const Duration(seconds: 10));
    await expectLater(recorder.flush(), completes);
  });

  test('close flushes the last position and then rejects reports', () async {
    final recorder = ProgressRecorder(
      repository,
      interval: const Duration(minutes: 10),
    );
    final item = _item('BV1');
    recorder.record(item, '77', const Duration(seconds: 42));
    await recorder.close();
    expect(
      (await repository.progress(_part('BV1', '77')))!.position,
      const Duration(seconds: 42),
    );

    final writesAfterClose = repository.writes;
    recorder.record(item, '77', const Duration(seconds: 99));
    await recorder.flush();
    expect(repository.writes, writesAfterClose);
    expect(
      (await repository.progress(_part('BV1', '77')))!.position,
      const Duration(seconds: 42),
      reason: 'a report after close must not be stored',
    );
  });

  test('closing twice is safe', () async {
    final recorder = ProgressRecorder(repository);
    recorder.record(_item('BV1'), '77', const Duration(seconds: 5));
    await recorder.close();
    await expectLater(recorder.close(), completes);
  });
}
