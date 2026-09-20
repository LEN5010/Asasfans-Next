import 'dart:convert';
import 'dart:typed_data';

import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/features/backup/data/backup_codec.dart';
import 'package:asasfans_next/features/backup/data/sqlite_backup_repository.dart';
import 'package:asasfans_next/features/backup/domain/personal_backup.dart';
import 'package:asasfans_next/features/library/data/sqlite_library_repository.dart';
import 'package:asasfans_next/features/library/domain/library_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_fixture.dart';

const video = ContentSnapshot(
  identity: ContentIdentity(source: ContentSource.bilibiliVideo, value: 'BV1'),
  title: '录播',
  body: '简介',
  authorName: '作者',
  authorId: '123',
  kind: LibraryMediaKind.video,
);

PlaybackPart part(String partId) =>
    PlaybackPart(identity: video.identity, partId: partId);

Map<String, dynamic> object(Uint8List bytes) =>
    jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
Uint8List bytesOf(Object value) =>
    Uint8List.fromList(utf8.encode(jsonEncode(value)));
Matcher invalid([BackupFailureKind kind = BackupFailureKind.invalid]) =>
    throwsA(isA<BackupFailure>().having((e) => e.kind, 'kind', kind));

void main() {
  late MemoryLocalDatabase db;
  late SqliteLibraryRepository library;
  late SqliteBackupRepository backup;
  final at = DateTime.utc(2026, 9, 21);
  setUp(() {
    db = MemoryLocalDatabase();
    library = SqliteLibraryRepository(
      db,
      clock: () => at,
      backgroundDecoding: false,
    );
    backup = SqliteBackupRepository(
      db,
      clock: () => at,
      onCommitted: library.notifyExternalCommit,
    );
  });
  tearDown(() async {
    await library.close();
    await db.close();
  });

  test('export declares version 4 and carries playback assets', () async {
    await library.saveProgress(
      video,
      '77',
      const Duration(seconds: 30),
      duration: const Duration(minutes: 10),
    );
    await library.addBookmark(
      video,
      '77',
      const Duration(minutes: 1),
      title: '名场面',
    );
    final root = object(await backup.export());
    expect(root['version'], BackupCodec.formatVersion);
    expect(BackupCodec.formatVersion, 4);
    final data = root['data'] as Map<String, dynamic>;
    expect(data['playback_progress'], hasLength(1));
    expect(data['playback_bookmarks'], hasLength(1));
    expect(
      (data['playback_progress'] as List).single,
      containsPair('part_id', '77'),
    );
  });

  test(
    'a v4 file restores progress and bookmarks into an empty store',
    () async {
      await library.saveProgress(
        video,
        '77',
        const Duration(seconds: 30),
        duration: const Duration(minutes: 10),
      );
      await library.addBookmark(
        video,
        '77',
        const Duration(minutes: 1),
        title: '记',
      );
      final exported = await backup.export();

      // A fresh store receives the file.
      final target = MemoryLocalDatabase();
      addTearDown(target.close);
      final targetLibrary = SqliteLibraryRepository(
        target,
        clock: () => at,
        backgroundDecoding: false,
      );
      addTearDown(targetLibrary.close);
      final targetBackup = SqliteBackupRepository(
        target,
        clock: () => at,
        onCommitted: targetLibrary.notifyExternalCommit,
      );
      await targetBackup.merge(await targetBackup.inspect(exported));

      final restored = await targetLibrary.progress(part('77'));
      expect(restored!.position, const Duration(seconds: 30));
      expect(restored.duration, const Duration(minutes: 10));
      expect((await targetLibrary.bookmarks(part('77'))).single.title, '记');
    },
  );

  test('a restore does not rewind a newer local position', () async {
    await library.saveProgress(video, '77', const Duration(seconds: 10));
    final exported = await backup.export();
    // The local store moves further along than the file.
    final later = SqliteLibraryRepository(
      db,
      clock: () => at.add(const Duration(hours: 1)),
      backgroundDecoding: false,
    );
    addTearDown(later.close);
    await later.saveProgress(video, '77', const Duration(minutes: 5));

    await backup.merge(await backup.inspect(exported));
    expect(
      (await library.progress(part('77')))!.position,
      const Duration(minutes: 5),
      reason: 'an older imported position must not win',
    );
  });

  test(
    'a part already finished locally stays finished after a restore',
    () async {
      await library.saveProgress(video, '77', const Duration(seconds: 10));
      final exported = await backup.export();
      final later = SqliteLibraryRepository(
        db,
        clock: () => at.add(const Duration(hours: 1)),
        backgroundDecoding: false,
      );
      addTearDown(later.close);
      await later.saveProgress(
        video,
        '77',
        const Duration(minutes: 10),
        duration: const Duration(minutes: 10),
      );
      expect((await library.progress(part('77')))!.completed, isTrue);

      await backup.merge(await backup.inspect(exported));
      expect((await library.progress(part('77')))!.completed, isTrue);
    },
  );

  test(
    'a v3 file still restores and leaves playback assets untouched',
    () async {
      await library.saveProgress(video, '77', const Duration(seconds: 30));
      final root = object(await backup.export());
      final data = root['data'] as Map<String, dynamic>;
      // Reduce the export to what a v3 writer produced.
      data.remove('playback_progress');
      data.remove('playback_bookmarks');
      root['version'] = 3;

      final imported = await backup.inspect(bytesOf(root));
      expect(imported.summary.counts['playback_progress'], 0);
      await backup.merge(imported);
      expect(
        (await library.progress(part('77')))!.position,
        const Duration(seconds: 30),
        reason: 'an older format does not clear newer assets',
      );
    },
  );

  test('progress referencing a missing snapshot is rejected', () async {
    await library.saveProgress(video, '77', const Duration(seconds: 30));
    final root = object(await backup.export());
    final data = root['data'] as Map<String, dynamic>;
    data['content_refs'] = <Object?>[];
    expect(() => backup.inspect(bytesOf(root)), invalid());
  });

  test('a bookmark whose end precedes its start is rejected', () async {
    await library.addBookmark(
      video,
      '77',
      const Duration(seconds: 30),
      end: const Duration(seconds: 90),
    );
    final root = object(await backup.export());
    final rows =
        (root['data'] as Map<String, dynamic>)['playback_bookmarks'] as List;
    (rows.single as Map<String, dynamic>)['end_ms'] = 1;
    expect(() => backup.inspect(bytesOf(root)), invalid());
  });

  test('a position beyond a known duration is rejected', () async {
    await library.saveProgress(
      video,
      '77',
      const Duration(seconds: 30),
      duration: const Duration(minutes: 10),
    );
    final root = object(await backup.export());
    final rows =
        (root['data'] as Map<String, dynamic>)['playback_progress'] as List;
    (rows.single as Map<String, dynamic>)['position_ms'] = 999999999;
    expect(() => backup.inspect(bytesOf(root)), invalid());
  });

  test(
    'a blank part id is rejected rather than imported as an empty key',
    () async {
      await library.saveProgress(video, '77', const Duration(seconds: 30));
      final root = object(await backup.export());
      final rows =
          (root['data'] as Map<String, dynamic>)['playback_progress'] as List;
      (rows.single as Map<String, dynamic>)['part_id'] = '   ';
      expect(() => backup.inspect(bytesOf(root)), invalid());
    },
  );

  test('an unknown future format version is refused as incompatible', () async {
    final root = object(await backup.export());
    root['version'] = 5;
    expect(
      () => backup.inspect(bytesOf(root)),
      invalid(BackupFailureKind.incompatible),
    );
  });

  test('a duplicate progress key in one file is rejected', () async {
    await library.saveProgress(video, '77', const Duration(seconds: 30));
    final root = object(await backup.export());
    final rows =
        (root['data'] as Map<String, dynamic>)['playback_progress'] as List;
    rows.add(Map<String, dynamic>.from(rows.single as Map<String, dynamic>));
    expect(() => backup.inspect(bytesOf(root)), invalid());
  });
}
