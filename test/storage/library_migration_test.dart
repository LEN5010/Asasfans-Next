import 'package:asasfans_next/core/storage/local_database.dart';
import 'package:asasfans_next/core/storage/library_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void _v1(Database database) {
  database.execute(
    'CREATE TABLE preferences (key TEXT NOT NULL PRIMARY KEY,value TEXT NOT NULL) WITHOUT ROWID',
  );
  database.execute(
    'CREATE TABLE calendar_cache (source TEXT NOT NULL PRIMARY KEY,body TEXT NOT NULL,fetched_at INTEGER NOT NULL,etag TEXT,last_modified TEXT,stale INTEGER NOT NULL DEFAULT 0) WITHOUT ROWID',
  );
  database.execute('PRAGMA application_id = ${SqliteExecutor.applicationId}');
  database.userVersion = 1;
  database.execute("INSERT INTO preferences VALUES ('appearance','dark')");
  database.execute(
    "INSERT INTO calendar_cache VALUES ('https://example.com/calendar.ics','original',1,'original-etag',NULL,0)",
  );
}

void main() {
  test(
    'version 1 upgrades to personal assets without losing preferences or cached calendars',
    () {
      final database = sqlite3.openInMemory();
      addTearDown(database.dispose);
      _v1(database);
      SqliteExecutor.initialize(database);
      expect(database.userVersion, SqliteExecutor.schemaVersion);
      expect(
        database.select('SELECT value FROM preferences').single['value'],
        'dark',
      );
      expect(
        database.select('SELECT etag FROM calendar_cache').single['etag'],
        'original-etag',
      );
      expect(
        database.select('SELECT id FROM collection_folders').single['id'],
        'default',
      );
      SqliteExecutor.initialize(database);
      expect(database.select('SELECT * FROM collection_folders'), hasLength(1));
    },
  );
  test('failed upgrade rolls back all new tables and preserves version 1', () {
    final database = sqlite3.openInMemory();
    addTearDown(database.dispose);
    _v1(database);
    database.execute('CREATE TABLE local_subscriptions (unexpected TEXT)');
    expect(
      () => SqliteExecutor.initialize(database),
      throwsA(isA<SqliteException>()),
    );
    expect(database.userVersion, 1);
    expect(
      database.select(
        "SELECT name FROM sqlite_master WHERE name='content_refs'",
      ),
      isEmpty,
    );
    expect(
      database.select('SELECT value FROM preferences').single['value'],
      'dark',
    );
  });
  test(
    'v2 upgrade preserves assets and initializes one durable revision identity',
    () {
      final database = sqlite3.openInMemory();
      addTearDown(database.dispose);
      _v1(database);
      for (final statement in librarySchemaV2) {
        database.execute(statement);
      }
      database.userVersion = 2;
      database.execute(
        "INSERT INTO local_subscriptions VALUES('123','name',NULL,1)",
      );
      SqliteExecutor.initialize(database);
      final meta = database.select('SELECT * FROM library_meta').single;
      expect(meta['revision'], 0);
      expect((meta['store_id'] as String).length, 32);
      database.execute(
        "UPDATE local_subscriptions SET name='new' WHERE mid='123'",
      );
      expect(
        database.select('SELECT revision FROM library_meta').single['revision'],
        1,
      );
      database.execute(
        "UPDATE local_subscriptions SET name='new' WHERE mid='123'",
      );
      database.execute("UPDATE calendar_cache SET stale=1");
      database.execute("UPDATE preferences SET value='light'");
      expect(
        database.select('SELECT revision FROM library_meta').single['revision'],
        1,
      );
      SqliteExecutor.initialize(database);
      expect(
        database.select('SELECT store_id FROM library_meta').single['store_id'],
        meta['store_id'],
      );
      database.execute('BEGIN');
      database.execute("DELETE FROM local_subscriptions");
      database.execute('ROLLBACK');
      expect(
        database.select('SELECT revision FROM library_meta').single['revision'],
        1,
      );
      expect(
        database.select('SELECT name FROM local_subscriptions').single['name'],
        'new',
      );
    },
  );
  test(
    'failed v2 migration keeps v2 assets and does not partially add indexes',
    () {
      final database = sqlite3.openInMemory();
      addTearDown(database.dispose);
      _v1(database);
      for (final statement in librarySchemaV2) {
        database.execute(statement);
      }
      database.userVersion = 2;
      database.execute('CREATE INDEX later_page ON watch_later(source)');
      expect(
        () => SqliteExecutor.initialize(database),
        throwsA(isA<SqliteException>()),
      );
      expect(database.userVersion, 2);
      expect(
        database.select(
          "SELECT name FROM sqlite_master WHERE name='library_meta'",
        ),
        isEmpty,
      );
      expect(
        database.select('SELECT id FROM collection_folders').single['id'],
        'default',
      );
    },
  );
}
