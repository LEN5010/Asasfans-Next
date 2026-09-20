import 'dart:async';
import 'dart:io';

import 'package:asasfans_next/core/storage/local_database.dart';
import 'package:asasfans_next/core/storage/storage_failure.dart';
import 'package:asasfans_next/features/preferences/data/sqlite_preferences_repository.dart';
import 'package:asasfans_next/features/preferences/domain/app_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import '../helpers/sqlite_fixture.dart';

void main() {
  test(
    'schema initialization is versioned, identifiable and idempotent',
    () async {
      final store = MemoryLocalDatabase();
      addTearDown(store.close);
      expect(store.database.userVersion, SqliteExecutor.schemaVersion);
      expect(
        store.database.select('PRAGMA application_id').single.values.single,
        SqliteExecutor.applicationId,
      );
      await SqlitePreferencesRepository(
        store,
      ).setAppearance(AppAppearance.dark);
      SqliteExecutor.initialize(store.database);
      expect(
        (await SqlitePreferencesRepository(store).load()).appearance,
        AppAppearance.dark,
      );
    },
  );

  test(
    'a failed transaction rolls back earlier writes and permits retry',
    () async {
      final store = MemoryLocalDatabase();
      addTearDown(store.close);
      await expectLater(
        store.batch(const [
          SqlStatement('INSERT INTO preferences(key, value) VALUES (?, ?)', [
            'key',
            'sensitive fixture',
          ]),
          SqlStatement('INSERT INTO preferences(key, value) VALUES (?, ?)', [
            'key',
            'duplicate',
          ]),
        ], write: true),
        throwsA(
          isA<StorageFailure>().having(
            (e) => e.toString(),
            'redacted',
            'StorageFailure(unavailable)',
          ),
        ),
      );
      expect(
        (await store.batch(const [
          SqlStatement('SELECT * FROM preferences', [], true),
        ])).single,
        isEmpty,
      );
      await SqlitePreferencesRepository(
        store,
      ).setAppearance(AppAppearance.light);
      expect(
        (await SqlitePreferencesRepository(store).load()).appearance,
        AppAppearance.light,
      );
    },
  );

  test(
    'foreign and future stores are rejected without resetting their data',
    () {
      final foreign = sqlite3.openInMemory();
      addTearDown(foreign.dispose);
      foreign.execute('CREATE TABLE unrelated(value TEXT)');
      foreign.execute("INSERT INTO unrelated VALUES ('preserve')");
      expect(
        () => SqliteExecutor.initialize(foreign),
        throwsA(
          isA<StorageFailure>().having(
            (e) => e.kind,
            'kind',
            StorageFailureKind.incompatible,
          ),
        ),
      );
      expect(foreign.userVersion, 0);
      expect(
        foreign.select('SELECT value FROM unrelated').single['value'],
        'preserve',
      );

      final future = sqlite3.openInMemory();
      addTearDown(future.dispose);
      SqliteExecutor.initialize(future);
      future.execute("INSERT INTO preferences VALUES ('appearance', 'dark')");
      future.userVersion = 99;
      expect(
        () => SqliteExecutor.initialize(future),
        throwsA(isA<StorageFailure>()),
      );
      expect(future.userVersion, 99);
      expect(
        future.select('SELECT value FROM preferences').single['value'],
        'dark',
      );
    },
  );

  test(
    'isolated queue persists across new connections and survives a failed batch',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'asasfans-newstore-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/personal.sqlite3';
      var resolutions = 0;
      final store = IsolateLocalDatabase(() async {
        resolutions++;
        return path;
      });
      final preferences = SqlitePreferencesRepository(store);
      await Future.wait([
        preferences.setAppearance(AppAppearance.dark),
        preferences.setHomeSection(HomeSection.clips, false),
      ]);
      await expectLater(
        store.batch(const [SqlStatement('NOT VALID SQL')]),
        throwsA(isA<StorageFailure>()),
      );
      await preferences.setHomeSection(HomeSection.fanart, false);
      expect(resolutions, 1);
      await store.close();
      await expectLater(
        store.batch(const []),
        throwsA(
          isA<StorageFailure>().having(
            (e) => e.kind,
            'kind',
            StorageFailureKind.closed,
          ),
        ),
      );
      final reopened = IsolateLocalDatabase(() async => path);
      addTearDown(reopened.close);
      final saved = await SqlitePreferencesRepository(reopened).load();
      expect(saved.appearance, AppAppearance.dark);
      expect(saved.hiddenHomeSections, {HomeSection.clips, HomeSection.fanart});
    },
  );

  test(
    'close drains accepted writes and rejects new work while a path is pending',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'asasfans-close-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final gate = Completer<String>();
      final store = IsolateLocalDatabase(() => gate.future);
      final write = SqlitePreferencesRepository(
        store,
      ).setAppearance(AppAppearance.dark);
      final close = store.close();
      await expectLater(store.batch(const []), throwsA(isA<StorageFailure>()));
      gate.complete('${directory.path}/personal.sqlite3');
      await write;
      await close;
      final reopened = IsolateLocalDatabase(
        () async => '${directory.path}/personal.sqlite3',
      );
      addTearDown(reopened.close);
      expect(
        (await SqlitePreferencesRepository(reopened).load()).appearance,
        AppAppearance.dark,
      );
    },
  );
}
