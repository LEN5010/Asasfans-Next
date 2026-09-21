import 'dart:convert';
import 'dart:typed_data';

import 'package:asasfans_next/features/backup/data/backup_codec.dart';
import 'package:asasfans_next/features/backup/data/sqlite_backup_repository.dart';
import 'package:asasfans_next/features/backup/domain/personal_backup.dart';
import 'package:asasfans_next/features/content/data/sqlite_channel_repository.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/features/content/domain/saved_channel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/backup_fixture.dart';
import '../helpers/sqlite_fixture.dart';

void main() {
  late MemoryLocalDatabase db;
  late SqliteChannelRepository channels;
  late SqliteBackupRepository backups;
  var committed = 0;
  setUp(() {
    committed = 0;
    db = MemoryLocalDatabase();
    channels = SqliteChannelRepository(
      db,
      clock: () => DateTime.utc(2026, 9, 21),
    );
    backups = SqliteBackupRepository(db, onCommitted: () => committed++);
  });
  tearDown(() async {
    await channels.close();
    await db.close();
  });

  /// A second store standing in for a fresh install.
  Future<(MemoryLocalDatabase, SqliteChannelRepository, SqliteBackupRepository)>
  emptyTarget() async {
    final target = MemoryLocalDatabase();
    final repository = SqliteChannelRepository(
      target,
      clock: () => DateTime.utc(2026, 9, 22),
    );
    final restore = SqliteBackupRepository(target, onCommitted: () {});
    addTearDown(() async {
      await repository.close();
      await target.close();
    });
    return (target, repository, restore);
  }

  test(
    'named channels reach an empty store with their queries intact',
    () async {
      await channels.save(
        '嘉然生日',
        ChannelFeed.fanart,
        ChannelSpec.ofFanart(
          const FanartQuery(
            keyword: '生日',
            characters: {FanartCharacter.diana},
            contentType: FanartContentType.video,
          ),
        ),
      );
      final id = await channels.save(
        '旧名',
        ChannelFeed.fanart,
        ChannelSpec.ofFanart(const FanartQuery(keyword: '切片')),
      );
      await channels.rename(id, '改过的名字');
      final saved = await channels.channels();
      expect(saved, hasLength(2));

      final bytes = await backups.export();
      expect(
        jsonDecode(utf8.decode(bytes))['version'],
        BackupCodec.formatVersion,
      );

      final (_, restored, restore) = await emptyTarget();
      await restore.merge(await restore.inspect(bytes));
      final copies = await restored.channels();
      expect(copies.map((c) => c.name), saved.map((c) => c.name));
      expect(copies.map((c) => c.feed), saved.map((c) => c.feed));
      expect(copies.map((c) => c.position), saved.map((c) => c.position));
      // The query itself, not just the label.
      final query = copies.first.spec.toFanart();
      expect(query.keyword, '生日');
      expect(query.characters, {FanartCharacter.diana});
      expect(query.contentType, FanartContentType.video);
      expect(copies.last.spec.toFanart().keyword, '切片');
    },
  );

  test('importing the same file twice does not duplicate a channel', () async {
    await channels.save(
      '频道',
      ChannelFeed.fanart,
      ChannelSpec.ofFanart(const FanartQuery(keyword: '一')),
    );
    final bytes = await backups.export();
    final (_, restored, restore) = await emptyTarget();
    await restore.merge(await restore.inspect(bytes));
    await restore.merge(await restore.inspect(bytes));
    expect(await restored.channels(), hasLength(1));
  });

  test('a restore never renames or requeries a local channel', () async {
    final id = await channels.save(
      '同名',
      ChannelFeed.fanart,
      ChannelSpec.ofFanart(const FanartQuery(keyword: '导出时的查询')),
    );
    final bytes = await backups.export();

    // Same name in the same feed, different id and different query: the local
    // definition is the one the user can see, so it must survive.
    final (_, local, restore) = await emptyTarget();
    await local.save(
      '同名',
      ChannelFeed.fanart,
      ChannelSpec.ofFanart(const FanartQuery(keyword: '本地的查询')),
    );
    await restore.merge(await restore.inspect(bytes));
    final after = await local.channels();
    expect(after, hasLength(1));
    expect(after.single.name, '同名');
    expect(after.single.spec.toFanart().keyword, '本地的查询');
    expect(after.single.id, isNot(id));
  });

  test('an older backup leaves newer local channels alone', () async {
    await channels.save(
      '本地频道',
      ChannelFeed.fanart,
      ChannelSpec.ofFanart(const FanartQuery(keyword: '保留')),
    );
    final bytes = await backups.export();
    for (final version in [1, 2, 3, 4]) {
      final older = downgradeBackup(bytes, version);
      final decoded = BackupCodec.decode(older);
      expect(decoded.summary.counts['saved_channels'], 0);
      await backups.merge(decoded);
      final kept = await channels.channels();
      expect(kept.single.name, '本地频道');
      expect(kept.single.spec.toFanart().keyword, '保留');
    }
  });

  test('a rejected file commits no channel at all', () async {
    await channels.save(
      '好频道',
      ChannelFeed.fanart,
      ChannelSpec.ofFanart(const FanartQuery()),
    );
    final raw =
        jsonDecode(utf8.decode(await backups.export())) as Map<String, dynamic>;
    final rows = raw['data']['saved_channels'] as List<Object?>;
    final good = Map<String, Object?>.from(rows.single as Map);

    for (final mutate in <void Function(Map<String, Object?>)>[
      (row) => row['feed'] = 'nonexistent',
      (row) => row['spec_version'] = 0,
      (row) => row['spec'] = 'not json',
      (row) => row['spec'] = '[]',
      (row) => row['name'] = '  带空格的名字  ',
      (row) => row['name'] = '',
    ]) {
      final broken = Map<String, Object?>.from(good);
      mutate(broken);
      raw['data']['saved_channels'] = [broken];
      expect(
        () => BackupCodec.decode(
          Uint8List.fromList(utf8.encode(jsonEncode(raw))),
        ),
        throwsA(isA<BackupFailure>()),
        reason: 'rejected before any row is written',
      );
    }

    final (target, restored, restore) = await emptyTarget();
    raw['data']['saved_channels'] = [
      good,
      {...good, 'id': 'b' * 32, 'name': '第二个', 'feed': 'nonexistent'},
    ];
    await expectLater(
      restore.inspect(Uint8List.fromList(utf8.encode(jsonEncode(raw)))),
      throwsA(isA<BackupFailure>()),
    );
    expect(await restored.channels(), isEmpty);
    expect(
      target.database.select('SELECT * FROM saved_channels'),
      isEmpty,
      reason: 'no partial commit from a file with one bad row',
    );
  });

  test('a spec this build cannot read survives the round trip', () async {
    await channels.save(
      '未来频道',
      ChannelFeed.fanart,
      ChannelSpec.ofFanart(const FanartQuery(keyword: '以后')),
    );
    // A later build's shape. The reader skips it rather than guessing, but a
    // backup must not be where it silently disappears.
    db.database.execute('UPDATE saved_channels SET spec_version=?', [
      ChannelSpec.currentVersion + 1,
    ]);
    final bytes = await backups.export();
    final (target, restored, restore) = await emptyTarget();
    await restore.merge(await restore.inspect(bytes));
    expect(
      await restored.channels(),
      isEmpty,
      reason: 'a too-new spec is still skipped on read',
    );
    expect(
      target.database
          .select('SELECT spec_version,name FROM saved_channels')
          .single,
      {'spec_version': ChannelSpec.currentVersion + 1, 'name': '未来频道'},
      reason: 'but the row itself was carried over',
    );
  });

  test('a committed import wakes channel subscribers', () async {
    final bytes = await backups.export();
    await backups.merge(await backups.inspect(bytes));
    expect(committed, 1);
  });
}
