import 'dart:convert';

import 'package:asasfans_next/features/backup/data/backup_codec.dart';
import 'package:asasfans_next/features/backup/data/sqlite_backup_repository.dart';
import 'package:asasfans_next/features/backup/domain/personal_backup.dart';
import 'package:asasfans_next/features/library/data/sqlite_library_repository.dart';
import 'package:asasfans_next/features/music/domain/music_track.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/backup_fixture.dart';
import '../helpers/sqlite_fixture.dart';

final _song = MusicTrack(
  id: '1999999999',
  date: DateTime(2026, 9, 17),
  title: '太聪明',
  members: const ['嘉然', '贝拉'],
  duration: const Duration(minutes: 4, seconds: 21),
  status: 'Live',
);

void main() {
  SqliteLibraryRepository library(MemoryLocalDatabase db) =>
      SqliteLibraryRepository(
        db,
        clock: () => DateTime.utc(2026, 10, 16),
        backgroundDecoding: false,
      );

  test('a kept song reads back whole and leaves on unkeep', () async {
    final db = MemoryLocalDatabase();
    final store = library(db);
    await store.setMusicFavorite(_song, true);
    await store.setMusicFavorite(_song, true);
    expect(await store.musicFavoriteIds(), {_song.id});
    final page = await store.musicFavoritePage();
    final kept = page.items.single.track;
    expect(
      [
        kept.id,
        kept.title,
        kept.members,
        kept.date,
        kept.duration,
        kept.isLive,
      ],
      [_song.id, _song.title, _song.members, _song.date, _song.duration, true],
    );
    await store.setMusicFavorite(_song, false);
    expect(await store.musicFavoriteIds(), isEmpty);
    expect((await store.musicFavorites()), isEmpty);
  });

  test('kept songs go through a backup and older files still read', () async {
    final source = MemoryLocalDatabase();
    await library(source).setMusicFavorite(_song, true);
    final bytes = await SqliteBackupRepository(
      source,
      onCommitted: () {},
    ).export();
    final root = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    expect(root['version'], BackupCodec.formatVersion);
    expect((root['data'] as Map)['music_favorites'], hasLength(1));

    final target = MemoryLocalDatabase();
    final backup = SqliteBackupRepository(target, onCommitted: () {});
    await backup.merge(await backup.inspect(bytes));
    expect(await library(target).musicFavoriteIds(), {_song.id});

    // A version 7 file has no kept songs, and reads as none.
    expect(
      BackupCodec.decode(downgradeBackup(bytes, 7)).tables['music_favorites'],
      isEmpty,
    );

    // A song id that is not the service's number is refused.
    final rows = (root['data'] as Map)['music_favorites'] as List;
    (rows.single as Map)['song_id'] = 'x';
    ((rows.single as Map)['snapshot'] as Map)['id'] = 'x';
    expect(
      () => BackupCodec.decode(utf8.encode(jsonEncode(root))),
      throwsA(isA<BackupFailure>()),
    );
  });
}
