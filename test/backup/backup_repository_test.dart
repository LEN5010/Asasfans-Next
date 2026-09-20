import 'dart:convert';
import 'dart:typed_data';

import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/core/storage/local_database.dart';
import 'package:asasfans_next/core/storage/storage_failure.dart';
import 'package:asasfans_next/features/backup/data/backup_codec.dart';
import 'package:asasfans_next/features/backup/data/backup_files.dart';
import 'package:asasfans_next/features/backup/data/sqlite_backup_repository.dart';
import 'package:asasfans_next/features/backup/domain/personal_backup.dart';
import 'package:asasfans_next/features/calendar/domain/calendar_event.dart';
import 'package:asasfans_next/features/library/data/sqlite_library_repository.dart';
import 'package:asasfans_next/features/library/domain/library_models.dart';
import 'package:asasfans_next/features/library/domain/library_page.dart';
import 'package:asasfans_next/features/preferences/data/sqlite_preferences_repository.dart';
import 'package:asasfans_next/features/preferences/domain/app_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_fixture.dart';

const content = ContentSnapshot(
  identity: ContentIdentity(
    source: ContentSource.bilibiliDynamic,
    value: '123',
  ),
  title: '我的收藏',
  body: '正文',
  authorName: '作者',
  authorId: '123',
);
final source = Uri.https('calendar.example', '/calendar.ics');
final key = CalendarFollowKey(source: source, uid: 'event');
CalendarEvent event(int sequence) => CalendarEvent(
  uid: 'event',
  title: '改期 $sequence',
  start: DateTime.utc(2026, 9, 21, 12),
  end: DateTime.utc(2026, 9, 21, 13),
  allDay: false,
  sequence: sequence,
);
Uint8List encode(Object value) =>
    Uint8List.fromList(utf8.encode(jsonEncode(value)));
Map<String, dynamic> object(Uint8List bytes) =>
    jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
Matcher invalid([BackupFailureKind kind = BackupFailureKind.invalid]) =>
    throwsA(isA<BackupFailure>().having((e) => e.kind, 'kind', kind));

void main() {
  late MemoryLocalDatabase db;
  late SqliteLibraryRepository library;
  late SqliteBackupRepository backup;
  var notifications = 0;
  final at = DateTime.utc(2026, 9, 21);
  setUp(() {
    notifications = 0;
    db = MemoryLocalDatabase();
    library = SqliteLibraryRepository(
      db,
      clock: () => at,
      backgroundDecoding: false,
    );
    backup = SqliteBackupRepository(
      db,
      clock: () => at,
      onCommitted: () {
        notifications++;
        library.notifyExternalCommit();
      },
    );
  });
  tearDown(() async {
    await library.close();
    await db.close();
  });

  Future<void> seed() async {
    await library.setCollected(content, 'default', true);
    final folder = await library.createFolder('精选');
    await library.setCollected(content, folder, true);
    await library.setLater(content, true);
    await library.recordHistory(content, HistoryAction.detail);
    await library.recordHistory(content, HistoryAction.external);
    await library.subscribe(const LocalSubscription(mid: '123', name: '原名'));
    await library.followCalendar(key, event(1));
    await library.synchronizeCalendar(source, [event(1)], at);
    await SqlitePreferencesRepository(db).setAppearance(AppAppearance.dark);
    await db.batch([
      const SqlStatement(
        "INSERT INTO calendar_cache VALUES('https://cache.example','PRIVATE_CACHE',1,NULL,NULL,0)",
      ),
    ], write: true);
  }

  test(
    'roundtrip preserves assets and relationships, not caches or internal cursor identity',
    () async {
      await seed();
      final bytes = await backup.export();
      final raw = utf8.decode(bytes);
      for (final forbidden in [
        'PRIVATE_CACHE',
        'calendar_cache',
        'library_meta',
        'store_id',
        'revision',
        'SESSDATA',
        'mediaUrl',
      ]) {
        expect(raw, isNot(contains(forbidden)));
      }
      final imported = await backup.inspect(bytes);
      expect(imported.summary.counts['collection_items'], 2);
      final targetDb = MemoryLocalDatabase();
      final targetLibrary = SqliteLibraryRepository(targetDb);
      addTearDown(() async {
        await targetLibrary.close();
        await targetDb.close();
      });
      var commits = 0;
      final target = SqliteBackupRepository(
        targetDb,
        onCommitted: () => commits++,
      );
      await target.merge(imported);
      expect(await targetLibrary.folders(), hasLength(2));
      expect(
        (await targetLibrary.itemState(content.identity)).folderIds,
        hasLength(2),
      );
      expect((await targetLibrary.later()).single.done, isFalse);
      expect((await targetLibrary.history()).map((r) => r.action).toSet(), {
        HistoryAction.detail,
        HistoryAction.external,
      });
      expect((await targetLibrary.calendarFollows()).single.event.sequence, 1);
      expect(
        (await SqlitePreferencesRepository(targetDb).load()).appearance,
        AppAppearance.dark,
      );
      expect(targetDb.database.select('SELECT * FROM calendar_cache'), isEmpty);
      expect(commits, 1);
      final rows = (imported as ValidatedBackup).tables;
      expect(
        () => rows['local_subscriptions']!.single['name'] =
            'change after preview',
        throwsUnsupportedError,
      );
    },
  );
  test(
    'repeated merge is idempotent and local states plus newer history and follows survive',
    () async {
      await seed();
      final exported = await backup.inspect(await backup.export());
      final folder = (await library.folders()).firstWhere((f) => !f.isDefault);
      await library.renameFolder(folder.id, '本机命名');
      await library.setLaterDone(content.identity, true);
      await library.subscribe(
        const LocalSubscription(mid: '123', name: '本机昵称'),
      );
      await library.recordHistory(content, HistoryAction.detail);
      await library.synchronizeCalendar(source, [
        event(3),
      ], at.add(const Duration(days: 1)));
      await SqlitePreferencesRepository(db).setAppearance(AppAppearance.light);
      await backup.merge(exported);
      final first = await backup.export();
      final revision = db.database
          .select('SELECT revision FROM library_meta')
          .single['revision'];
      await backup.merge(exported);
      expect(await backup.export(), first);
      expect(
        db.database
            .select('SELECT revision FROM library_meta')
            .single['revision'],
        revision,
      );
      expect((await library.folder(folder.id))!.name, '本机命名');
      expect((await library.later()).single.done, isTrue);
      expect((await library.subscriptions()).single.name, '本机昵称');
      expect(
        (await library.history(action: HistoryAction.detail)).single.visits,
        2,
      );
      expect((await library.calendarFollows()).single.event.sequence, 3);
      expect(
        (await SqlitePreferencesRepository(db).load()).appearance,
        AppAppearance.light,
      );
      expect(notifications, 2);
    },
  );
  test(
    'transaction failure rolls back preferences and all preceding inserts with no notification',
    () async {
      await seed();
      final exported = await backup.inspect(await backup.export());
      final target = MemoryLocalDatabase();
      addTearDown(target.close);
      target.database.execute(
        "CREATE TRIGGER reject_history BEFORE INSERT ON content_history BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      var commits = 0;
      final importer = SqliteBackupRepository(
        target,
        onCommitted: () => commits++,
      );
      await expectLater(
        importer.merge(exported),
        throwsA(isA<StorageFailure>()),
      );
      for (final table in [
        'preferences',
        'content_refs',
        'collection_items',
        'watch_later',
        'content_history',
        'local_subscriptions',
        'calendar_follows',
      ]) {
        expect(
          target.database.select('SELECT * FROM $table'),
          isEmpty,
          reason: table,
        );
      }
      expect(
        target.database.select('SELECT * FROM collection_folders'),
        hasLength(1),
      );
      expect(
        target.database
            .select('SELECT revision FROM library_meta')
            .single['revision'],
        0,
      );
      expect(commits, 0);
    },
  );
  test(
    'merging modifies durable revision so a cursor from another repository cannot continue',
    () async {
      await seed();
      final exported = object(await backup.export());
      final data = exported['data'] as Map<String, dynamic>;
      data['local_subscriptions'].add({
        'mid': '456',
        'name': '新增',
        'avatar': null,
        'added_at': at.millisecondsSinceEpoch,
      });
      final first = await library.recordPage(
        const LibraryQuery.history(),
        limit: 1,
      );
      await backup.merge(await backup.inspect(encode(exported)));
      await expectLater(
        library.recordPage(const LibraryQuery.history(), cursor: first.next),
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
  test(
    'export budget blocks giant stores before returning full snapshots',
    () async {
      // A deliberately malformed fixture bypasses app write limits to exercise
      // the SQL size guard without allocating the huge value on the Dart side.
      await db.batch([
        const SqlStatement(
          "INSERT INTO content_refs VALUES('bilibiliDynamic','huge',zeroblob(18000000),1)",
        ),
      ], write: true);
      await expectLater(backup.export(), invalid(BackupFailureKind.tooLarge));
    },
  );
  test(
    'unknown version, credentials, duplicate identities, missing references and malformed values are rejected',
    () async {
      await seed();
      final original = await backup.export();
      final mutations = <void Function(Map<String, dynamic>)>[
        (r) => r['data']['credentials'] = {'SESSDATA': 'fixture'},
        (r) => r['data']['collection_items'].add(
          r['data']['collection_items'].first,
        ),
        (r) => r['data']['collection_items'][0]['folder_id'] = 'missing',
        (r) => r['data']['content_refs'][0]['content_id'] = 'wrong',
        (r) => r['data']['content_refs'][0]['snapshot']['mediaUrl'] =
            'https://cdn.example/signed',
        (r) => r['data']['content_refs'][0]['snapshot']['images'] = [
          'https://image.example/a?token=fixture',
        ],
        (r) => r['data']['calendar_follows'][0]['sequence'] = 99,
        (r) => r['data']['content_history'][0]['visits'] = 0,
        (r) => r['data']['watch_later'][0]['done'] = true,
        (r) => r['data']['local_subscriptions'][0]['added_at'] = -1,
        (r) => r['data']['preferences'][0]['key'] = 'Cookie',
        (r) => r['data']['collection_folders'] = <Object?>[],
      ];
      for (final mutation in mutations) {
        final raw = object(original);
        mutation(raw);
        expect(() => BackupCodec.decode(encode(raw)), invalid());
      }
      final newer = object(original)..['version'] = 99;
      expect(
        () => BackupCodec.decode(encode(newer)),
        invalid(BackupFailureKind.incompatible),
      );
      expect(() => BackupCodec.decode(Uint8List.fromList([0xff])), invalid());
      expect(
        () => BackupCodec.decode(
          Uint8List.fromList(
            utf8.encode(
              '${List.filled(30, '[').join()}0${List.filled(30, ']').join()}',
            ),
          ),
        ),
        invalid(),
      );
      expect(
        () => BackupCodec.decode(Uint8List(BackupCodec.maxBytes + 1)),
        invalid(BackupFailureKind.tooLarge),
      );
      expect(notifications, 0);
    },
  );
  test(
    'stream byte limit does not trust file length and cancels oversized reads',
    () async {
      var cancelled = false;
      Stream<List<int>> growingFile() async* {
        try {
          yield Uint8List(BackupCodec.maxBytes);
          yield [1];
          fail('reader consumed data after limit');
        } finally {
          cancelled = true;
        }
      }

      await expectLater(
        PlatformBackupFiles.readLimited(growingFile()),
        invalid(BackupFailureKind.tooLarge),
      );
      expect(cancelled, isTrue);
      expect(await PlatformBackupFiles.readLimited(Stream.value([1, 2, 3])), [
        1,
        2,
        3,
      ]);
    },
  );
}
