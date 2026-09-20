import 'package:asasfans_next/core/storage/local_database.dart';
import 'package:asasfans_next/core/storage/storage_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Builds a store at schema v5 through the real migration path, then seeds one
/// saved item so the playback tables have a legitimate reference target.
Database _v5() {
  final database = sqlite3.openInMemory();
  SqliteExecutor.initialize(database);
  expect(database.userVersion, SqliteExecutor.schemaVersion);
  database.execute(
    "INSERT INTO content_refs VALUES ('bilibiliVideo','BV1xx','{}',1)",
  );
  return database;
}

int _revision(Database database) =>
    database.select('SELECT revision FROM library_meta').single['revision']
        as int;

void main() {
  test('v6 adds playback tables and keeps existing personal assets', () {
    final database = _v5();
    addTearDown(database.dispose);
    expect(SqliteExecutor.schemaVersion, 6);
    expect(
      database.select('SELECT snapshot FROM content_refs').single['snapshot'],
      '{}',
    );
    expect(database.select('SELECT * FROM playback_progress'), isEmpty);
    expect(database.select('SELECT * FROM playback_bookmarks'), isEmpty);
    // Re-running the migration is a no-op rather than a reset.
    SqliteExecutor.initialize(database);
    expect(database.select('SELECT * FROM content_refs'), hasLength(1));
  });

  test('a position past a known duration is rejected by the table', () {
    final database = _v5();
    addTearDown(database.dispose);
    expect(
      () => database.execute(
        "INSERT INTO playback_progress VALUES ('bilibiliVideo','BV1xx','77',900,500,0,1)",
      ),
      throwsA(isA<SqliteException>()),
    );
    // An unknown duration is 0 and must not clamp a real position away.
    database.execute(
      "INSERT INTO playback_progress VALUES ('bilibiliVideo','BV1xx','77',900,0,0,1)",
    );
    expect(
      database
          .select('SELECT position_ms FROM playback_progress')
          .single['position_ms'],
      900,
    );
  });

  test('a negative position and an inverted bookmark range are rejected', () {
    final database = _v5();
    addTearDown(database.dispose);
    expect(
      () => database.execute(
        "INSERT INTO playback_progress VALUES ('bilibiliVideo','BV1xx','77',-1,0,0,1)",
      ),
      throwsA(isA<SqliteException>()),
    );
    expect(
      () => database.execute(
        "INSERT INTO playback_bookmarks VALUES ('b1','bilibiliVideo','BV1xx','77',500,499,'t','',1,1)",
      ),
      throwsA(isA<SqliteException>()),
    );
    // An end equal to the start is a valid zero-length range; NULL is a point.
    database.execute(
      "INSERT INTO playback_bookmarks VALUES ('b1','bilibiliVideo','BV1xx','77',500,500,'t','',1,1)",
    );
    database.execute(
      "INSERT INTO playback_bookmarks VALUES ('b2','bilibiliVideo','BV1xx','77',600,NULL,'t','',1,1)",
    );
    expect(database.select('SELECT * FROM playback_bookmarks'), hasLength(2));
  });

  test('playback rows require an existing content reference', () {
    final database = _v5();
    addTearDown(database.dispose);
    expect(
      () => database.execute(
        "INSERT INTO playback_progress VALUES ('bilibiliVideo','missing','77',1,0,0,1)",
      ),
      throwsA(isA<SqliteException>()),
    );
    expect(
      () => database.execute(
        "INSERT INTO playback_bookmarks VALUES ('b1','bilibiliVideo','missing','77',1,NULL,'t','',1,1)",
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('progress and bookmark writes advance the cursor revision', () {
    final database = _v5();
    addTearDown(database.dispose);
    final start = _revision(database);
    database.execute(
      "INSERT INTO playback_progress VALUES ('bilibiliVideo','BV1xx','77',10,100,0,1)",
    );
    final afterInsert = _revision(database);
    expect(afterInsert, greaterThan(start));

    database.execute(
      'UPDATE playback_progress SET position_ms=20,updated_at=2',
    );
    final afterUpdate = _revision(database);
    expect(afterUpdate, greaterThan(afterInsert));

    // An update that changes nothing must not invalidate live cursors.
    database.execute(
      'UPDATE playback_progress SET position_ms=20,updated_at=2',
    );
    expect(_revision(database), afterUpdate);

    database.execute('DELETE FROM playback_progress');
    final afterDelete = _revision(database);
    expect(afterDelete, greaterThan(afterUpdate));

    database.execute(
      "INSERT INTO playback_bookmarks VALUES ('b1','bilibiliVideo','BV1xx','77',5,NULL,'t','',1,1)",
    );
    expect(_revision(database), greaterThan(afterDelete));
  });

  test('a future schema version is rejected instead of being reset', () {
    final database = _v5();
    addTearDown(database.dispose);
    database.userVersion = SqliteExecutor.schemaVersion + 1;
    expect(
      () => SqliteExecutor.initialize(database),
      throwsA(
        isA<StorageFailure>().having(
          (failure) => failure.kind,
          'kind',
          StorageFailureKind.incompatible,
        ),
      ),
    );
    expect(
      database.select('SELECT * FROM content_refs'),
      hasLength(1),
      reason: 'a rejected store keeps its data',
    );
  });
}
