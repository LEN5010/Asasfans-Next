import 'dart:convert';
import 'dart:typed_data';
import 'package:asasfans_next/core/storage/local_database.dart';
import 'package:asasfans_next/core/storage/storage_failure.dart';
import 'package:asasfans_next/features/backup/data/backup_codec.dart';
import 'package:asasfans_next/features/backup/data/sqlite_backup_repository.dart';
import 'package:asasfans_next/features/backup/domain/personal_backup.dart';
import 'package:asasfans_next/features/library/data/sqlite_library_repository.dart';
import 'package:asasfans_next/features/library/domain/library_models.dart';
import 'package:asasfans_next/features/subscriptions/data/sqlite_subscription_update_store.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/sqlite_fixture.dart';
import '../helpers/subscriptions_fixture.dart';

void main() {
  late MemoryLocalDatabase db;
  late SqliteLibraryRepository library;
  late SqliteSubscriptionUpdateStore store;
  setUp(() {
    db = MemoryLocalDatabase();
    library = SqliteLibraryRepository(db, backgroundDecoding: false);
    store = SqliteSubscriptionUpdateStore(db, clock: () => DateTime.utc(2026));
  });
  tearDown(() async {
    await store.close();
    await library.close();
    await db.close();
  });
  test(
    'roster revision observes remove/resubscribe even with identical MID; unrelated read writes do not invalidate it',
    () async {
      await library.subscribe(const LocalSubscription(mid: '123', name: 'UP'));
      final roster = await store.roster();
      final id = updateVideo(1).identity.value;
      final oldRevision =
          db.database
                  .select('SELECT revision FROM library_meta')
                  .single['revision']
              as int;
      await store.mark([id], read: true);
      await store.checkRoster(roster);
      expect(
        db.database
            .select('SELECT revision FROM library_meta')
            .single['revision'],
        greaterThan(oldRevision),
      );
      await library.unsubscribe('123');
      await library.subscribe(const LocalSubscription(mid: '123', name: 'UP'));
      await expectLater(
        store.checkRoster(roster),
        throwsA(
          isA<StorageFailure>().having(
            (e) => e.kind,
            'kind',
            StorageFailureKind.changed,
          ),
        ),
      );
      expect(await store.readStates([id]), {id: true});
      expect(await library.history(), isEmpty);
      expect(await library.collection('default'), isEmpty);
    },
  );
  test(
    'receipts persist through store recreation and explicit unread is durable',
    () async {
      final ids = List.generate(901, (i) => updateVideo(i).identity.value);
      await store.mark(ids, read: true);
      expect(await store.readStates(ids), hasLength(901));
      await store.mark([ids.first], read: false);
      final reopened = SqliteSubscriptionUpdateStore(db);
      addTearDown(reopened.close);
      final values = await reopened.readStates(ids);
      expect(values[ids.first], isFalse);
      expect(values[ids.last], isTrue);
      await expectLater(
        store.mark(['bad'], read: true),
        throwsA(isA<StorageFailure>()),
      );
      expect((await store.readStates(ids)).length, 901);
    },
  );
  test(
    'v4 upgrade keeps assets/store identity and initializes independent roster revision',
    () async {
      await library.subscribe(
        const LocalSubscription(mid: '123', name: 'retained'),
      );
      final before = await store.roster();
      removeSubscriptionV5Fixture(db.database);
      SqliteExecutor.initialize(db.database);
      final after = await store.roster();
      expect(after.storeId, before.storeId);
      expect(after.revision, 0);
      expect(after.creators.single.name, 'retained');
      expect(db.database.userVersion, SqliteExecutor.schemaVersion);
      expect(await store.readStates([updateVideo(1).identity.value]), isEmpty);
    },
  );
  test(
    'failed v4 upgrade rolls back new receipts table and leaves original assets',
    () async {
      await library.subscribe(
        const LocalSubscription(mid: '123', name: 'retained'),
      );
      removeSubscriptionV5Fixture(db.database);
      db.database.execute('CREATE TABLE subscription_meta (unexpected TEXT)');
      expect(() => SqliteExecutor.initialize(db.database), throwsException);
      expect(db.database.userVersion, 4);
      expect(
        db.database.select(
          "SELECT name FROM sqlite_master WHERE name='subscription_reads'",
        ),
        isEmpty,
      );
      expect(
        db.database
            .select('SELECT name FROM local_subscriptions')
            .single['name'],
        'retained',
      );
    },
  );
  test(
    'the current backup restores receipts without content FK; local unread wins and v1/v2 never clear them',
    () async {
      final id = updateVideo(1).identity.value;
      await store.mark([id], read: true);
      final backups = SqliteBackupRepository(db, onCommitted: () {});
      final bytes = await backups.export();
      final raw = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      expect(raw['version'], BackupCodec.formatVersion);
      expect(raw['data']['subscription_meta'], isNull);
      expect(raw['data']['content_refs'], isEmpty);
      final target = MemoryLocalDatabase();
      final other = SqliteSubscriptionUpdateStore(target);
      addTearDown(() async {
        await other.close();
        await target.close();
      });
      final restore = SqliteBackupRepository(target, onCommitted: () {});
      await restore.merge(await restore.inspect(bytes));
      expect(await other.readStates([id]), {id: true});
      await other.mark([id], read: false);
      await restore.merge(await restore.inspect(bytes));
      expect(await other.readStates([id]), {id: false});
      for (final version in [1, 2]) {
        final old = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        old['version'] = version;
        (old['data'] as Map).remove('subscription_reads');
        if (version == 1) {
          (old['data'] as Map)
            ..remove('content_rules')
            ..remove('rule_settings');
        }
        final decoded = BackupCodec.decode(
          Uint8List.fromList(utf8.encode(jsonEncode(old))),
        );
        await restore.merge(decoded);
        expect(await other.readStates([id]), {id: false});
      }
      raw['data']['subscription_reads'][0]['is_read'] = true;
      expect(
        () => BackupCodec.decode(
          Uint8List.fromList(utf8.encode(jsonEncode(raw))),
        ),
        throwsA(isA<BackupFailure>()),
      );
    },
  );
}
