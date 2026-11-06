import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/core/storage/local_database.dart';
import 'package:asasfans_next/features/library/data/cloud_collections.dart';
import 'package:asasfans_next/features/library/data/sqlite_library_repository.dart';
import 'package:asasfans_next/features/library/domain/library_models.dart';
import 'package:asasfans_next/features/backup/data/sqlite_backup_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_fixture.dart';

const item = ContentSnapshot(
  identity: ContentIdentity(
    source: ContentSource.bilibiliDynamic,
    value: '123',
  ),
  title: '作品',
  body: '正文',
  authorName: '作者',
);

void main() {
  late MemoryLocalDatabase db;
  setUp(() => db = MemoryLocalDatabase());
  tearDown(() => db.close());

  test('v11 collections migrate into the local owner', () async {
    final old = MemoryLocalDatabase.at(11);
    addTearDown(old.close);
    final repository = SqliteLibraryRepository(old, backgroundDecoding: false);
    // Populate the actual old schema before migration.
    old.database.execute(
      "INSERT INTO collection_folders VALUES('old','旧收藏夹',1)",
    );
    SqliteExecutor.initialize(old.database);
    expect(old.database.userVersion, 12);
    expect(
      old.database
          .select("SELECT owner FROM collection_folders WHERE id='old'")
          .single['owner'],
      'local',
    );
    await repository.close();
  });

  test(
    'latest operation wins and an old acknowledgment preserves a newer edit',
    () async {
      final store = CloudCollections(db, 'a');
      await store.initialize(importLocal: false);
      final repository = SqliteLibraryRepository(
        db,
        owner: 'a',
        backgroundDecoding: false,
        clock: () => DateTime.utc(2026),
      );
      addTearDown(repository.close);
      await repository.setCollected(item, 'default', true);
      final submitted = await store.pending();
      await repository.setCollected(item, 'default', false);
      expect((await store.pending()).single['op'], 'remove');
      await store.acknowledge(submitted, {});
      expect((await store.pending()).single['op'], 'remove');
    },
  );

  test(
    'folder membership controls global collection and owners are separate',
    () async {
      await CloudCollections(db, 'a').initialize(importLocal: false);
      await CloudCollections(db, 'b').initialize(importLocal: false);
      final a = SqliteLibraryRepository(
        db,
        owner: 'a',
        backgroundDecoding: false,
      );
      final b = SqliteLibraryRepository(
        db,
        owner: 'b',
        backgroundDecoding: false,
      );
      addTearDown(a.close);
      addTearDown(b.close);
      final folder = await a.createFolder('分组');
      await a.setCollected(item, 'default', true);
      await a.setCollected(item, folder, true);
      await a.setCollected(item, 'default', false);
      expect((await CloudCollections(db, 'a').pending()).single['op'], 'add');
      expect((await b.itemState(item.identity)).folderIds, isEmpty);
      await a.deleteFolder(folder);
      expect(
        (await CloudCollections(db, 'a').pending()).single['op'],
        'remove',
      );
    },
  );

  test(
    'reconciliation imports remote items, removes missing items, preserves pending changes',
    () async {
      final store = CloudCollections(db, 'a');
      await store.initialize(importLocal: false);
      await store.reconcile([CloudFavorite('bili:123', 1, item)]);
      final a = SqliteLibraryRepository(
        db,
        owner: 'a',
        backgroundDecoding: false,
      );
      addTearDown(a.close);
      expect((await a.itemState(item.identity)).folderIds, {'default'});
      expect(await store.pending(), isEmpty);
      await store.reconcile([]);
      expect((await a.itemState(item.identity)).folderIds, isEmpty);
      await a.setCollected(item, 'default', true);
      await store.reconcile([]);
      expect((await a.itemState(item.identity)).folderIds, {'default'});
      await a.setCollected(item, 'default', false);
      await store.reconcile([CloudFavorite('bili:123', 1, item)]);
      expect((await a.itemState(item.identity)).folderIds, isEmpty);
    },
  );

  test(
    'visitor import copies once and backup contains only the selected owner',
    () async {
      final local = SqliteLibraryRepository(db, backgroundDecoding: false);
      addTearDown(local.close);
      await local.setCollected(item, 'default', true);
      await CloudCollections(db, 'a').initialize(importLocal: true);
      await CloudCollections(db, 'b').initialize(importLocal: false);
      final backupA = SqliteBackupRepository(
        db,
        owner: 'a',
        onCommitted: () {},
      );
      final backupB = SqliteBackupRepository(
        db,
        owner: 'b',
        onCommitted: () {},
      );
      final imported = await backupB.inspect(await backupA.export());
      expect(imported.summary.counts['collection_items'], 1);
      final empty = await backupA.inspect(await backupB.export());
      expect(empty.summary.counts['collection_items'], 0);
      await backupB.merge(imported);
      final b = SqliteLibraryRepository(
        db,
        owner: 'b',
        backgroundDecoding: false,
      );
      addTearDown(b.close);
      expect((await b.itemState(item.identity)).folderIds, {'default'});
      expect((await CloudCollections(db, 'b').pending()).single['op'], 'add');
    },
  );
}
