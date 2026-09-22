import 'package:asasfans_next/core/storage/channel_schema.dart';
import 'package:asasfans_next/core/storage/handoff_schema.dart';
import 'package:asasfans_next/core/storage/library_schema.dart';
import 'package:asasfans_next/core/storage/local_database.dart';
import 'package:asasfans_next/core/storage/playback_schema.dart';
import 'package:asasfans_next/core/storage/rules_schema.dart';
import 'package:asasfans_next/core/storage/storage_failure.dart';
import 'package:asasfans_next/core/storage/subscription_schema.dart';
import 'package:asasfans_next/core/storage/updates_schema.dart';
import 'package:sqlite3/sqlite3.dart';

/// Opens an in-memory database migrated only as far as [version].
///
/// The statements come from the same lists production applies, in the same
/// order, so the fixture holds the tables that version really had — never a
/// later version's tables under an older number, which would let a migration
/// re-create an existing table and hide a genuine structural conflict behind a
/// test-only failure.
///
/// Downgrading a current database cannot produce a historical one: dropping the
/// tables a version introduced still leaves every later version's tables in
/// place. Building upwards and stopping is the only way to get the real shape.
Database historicalDatabase(int version) {
  if (version < 1 || version > SqliteExecutor.schemaVersion) {
    throw ArgumentError.value(version, 'version', 'unsupported schema version');
  }
  final database = sqlite3.openInMemory();
  database.execute('PRAGMA foreign_keys = ON');
  database.execute('BEGIN IMMEDIATE');
  try {
    database.execute(
      'CREATE TABLE preferences (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL) WITHOUT ROWID',
    );
    database.execute('''CREATE TABLE calendar_cache (
      source TEXT NOT NULL PRIMARY KEY,
      body TEXT NOT NULL,
      fetched_at INTEGER NOT NULL CHECK (fetched_at >= 0),
      etag TEXT,
      last_modified TEXT,
      stale INTEGER NOT NULL DEFAULT 0 CHECK (stale IN (0, 1))
    ) WITHOUT ROWID''');
    database.execute('PRAGMA application_id = ${SqliteExecutor.applicationId}');
    for (final step in [
      (2, librarySchemaV2),
      (3, librarySchemaV3),
      (4, rulesSchemaV4),
      (5, subscriptionSchemaV5),
      (6, playbackSchemaV6),
      (7, channelSchemaV7),
      (8, handoffSchemaV8),
      (9, updatesSchemaV9),
    ]) {
      if (version < step.$1) break;
      for (final statement in step.$2) {
        database.execute(statement);
      }
    }
    database.userVersion = version;
    database.execute('COMMIT');
  } catch (_) {
    database.execute('ROLLBACK');
    database.dispose();
    rethrow;
  }
  return database;
}

/// Real SQL semantics with a disposable connection, never the app directory.
class MemoryLocalDatabase implements LocalDatabase {
  MemoryLocalDatabase() : database = sqlite3.openInMemory() {
    SqliteExecutor.initialize(database);
  }

  /// Wraps a database already migrated to a historical version, so a test can
  /// run the production upgrade against a structure that version really had.
  MemoryLocalDatabase.at(int version) : database = historicalDatabase(version);

  final Database database;
  bool _closed = false;
  @override
  Future<SqlResults> batch(
    List<SqlStatement> statements, {
    bool write = false,
  }) async {
    if (_closed) throw const StorageFailure(StorageFailureKind.closed);
    return SqliteExecutor.execute(database, statements, write: write);
  }

  @override
  Future<void> close() async {
    if (!_closed) {
      _closed = true;
      database.dispose();
    }
  }
}
