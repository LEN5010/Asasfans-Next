import 'dart:async';
import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart';

import 'storage_failure.dart';
import 'channel_schema.dart';
import 'handoff_schema.dart';
import 'library_schema.dart';
import 'playback_schema.dart';
import 'rules_schema.dart';
import 'subscription_schema.dart';

typedef SqlRow = Map<String, Object?>;
typedef SqlResults = List<List<SqlRow>>;

class SqlStatement {
  const SqlStatement(
    this.sql, [
    this.parameters = const [],
    this.returnsRows = false,
  ]);
  final String sql;
  final List<Object?> parameters;
  final bool returnsRows;
}

abstract interface class LocalDatabase {
  /// One transaction and one snapshot. Values are always bound parameters.
  Future<SqlResults> batch(List<SqlStatement> statements, {bool write = false});
  Future<void> close();
}

/// Resolves only this app's new store path. Native SQL runs off the UI isolate.
/// Each accepted batch closes its connection in finally, including rollback.
/// A short-lived isolate avoids native handles surviving hot restart or a
/// provider teardown; callers serialize writes and the SQLite busy timeout
/// bounds contention with another application process.
class IsolateLocalDatabase implements LocalDatabase {
  IsolateLocalDatabase(this._resolvePath);
  final Future<String> Function() _resolvePath;
  Future<String>? _path;
  Future<void> _tail = Future.value();
  bool _closed = false;

  Future<String> _databasePath() async {
    try {
      return await (_path ??= _resolvePath()).timeout(
        const Duration(seconds: 10),
      );
    } catch (_) {
      _path = null;
      throw const StorageFailure(StorageFailureKind.unavailable);
    }
  }

  @override
  Future<SqlResults> batch(
    List<SqlStatement> statements, {
    bool write = false,
  }) {
    if (_closed) {
      return Future.error(const StorageFailure(StorageFailureKind.closed));
    }
    // Freeze caller-owned lists before queuing: later edits cannot change a
    // transaction that the user has already approved.
    final commands = [
      for (final s in statements)
        SqlStatement(
          s.sql,
          List<Object?>.unmodifiable(
            s.parameters.map(
              (value) =>
                  value is List<int> ? List<int>.unmodifiable(value) : value,
            ),
          ),
          s.returnsRows,
        ),
    ];
    final result = _tail.then((_) async {
      final path = await _databasePath();
      try {
        return await _runIsolated(path, commands, write);
      } on StorageFailure {
        rethrow;
      } catch (_) {
        throw const StorageFailure(StorageFailureKind.unavailable);
      }
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  Future<void> close() async {
    _closed = true;
    // Accepted operations finish before shutdown. No fire-and-forget writes.
    await _tail;
  }
}

// Keep this closure outside the connection object. Capturing its Future queue
// or path-provider callback would send unsendable UI-isolate state.
Future<SqlResults> _runIsolated(
  String path,
  List<SqlStatement> statements,
  bool write,
) =>
    Isolate.run(() => SqliteExecutor.openBatch(path, statements, write: write));

/// Also usable with an in-memory SQLite connection in offline test source.
/// No importer exists: an unknown database identity is rejected, never reset.
abstract final class SqliteExecutor {
  static const applicationId = 0x4153464E;
  static const schemaVersion = 8;

  static SqlResults openBatch(
    String path,
    List<SqlStatement> statements, {
    bool write = false,
  }) {
    Database? database;
    try {
      database = sqlite3.open(path);
      initialize(database);
      return execute(database, statements, write: write);
    } on StorageFailure {
      rethrow;
    } catch (_) {
      throw const StorageFailure(StorageFailureKind.unavailable);
    } finally {
      database?.dispose();
    }
  }

  static void initialize(Database database) {
    database.execute('PRAGMA busy_timeout = 5000');
    database.execute('PRAGMA foreign_keys = ON');
    void validate() {
      final id =
          database.select('PRAGMA application_id').single.values.single as int;
      final version = database.userVersion;
      final hasTables = database
          .select(
            "SELECT name FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' LIMIT 1",
          )
          .isNotEmpty;
      if ((id != applicationId && (id != 0 || version != 0 || hasTables)) ||
          version > schemaVersion ||
          (id == applicationId && version == 0)) {
        throw const StorageFailure(StorageFailureKind.incompatible);
      }
    }

    validate();
    if (database.userVersion < schemaVersion) {
      database.execute('BEGIN IMMEDIATE');
      try {
        // Another process may have initialized after the first inspection.
        validate();
        if (database.userVersion == 0) {
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
          database.execute('PRAGMA application_id = $applicationId');
          database.userVersion = 1;
        }
        if (database.userVersion == 1) {
          for (final statement in librarySchemaV2) {
            database.execute(statement);
          }
          database.userVersion = 2;
        }
        if (database.userVersion == 2) {
          for (final statement in librarySchemaV3) {
            database.execute(statement);
          }
          database.userVersion = 3;
        }
        if (database.userVersion == 3) {
          for (final statement in rulesSchemaV4) {
            database.execute(statement);
          }
          database.userVersion = 4;
        }
        if (database.userVersion == 4) {
          for (final statement in subscriptionSchemaV5) {
            database.execute(statement);
          }
          database.userVersion = 5;
        }
        if (database.userVersion == 5) {
          for (final statement in playbackSchemaV6) {
            database.execute(statement);
          }
          database.userVersion = 6;
        }
        if (database.userVersion == 6) {
          for (final statement in channelSchemaV7) {
            database.execute(statement);
          }
          database.userVersion = 7;
        }
        if (database.userVersion == 7) {
          for (final statement in handoffSchemaV8) {
            database.execute(statement);
          }
          database.userVersion = 8;
        }
        database.execute('COMMIT');
      } catch (_) {
        database.execute('ROLLBACK');
        rethrow;
      }
    }
    // Keep crash recovery enabled. FULL makes an acknowledged write durable;
    // journal files belong solely to the new Flutter store directory.
    database.execute('PRAGMA journal_mode = WAL');
    database.execute('PRAGMA synchronous = FULL');
  }

  static SqlResults execute(
    Database database,
    List<SqlStatement> statements, {
    bool write = false,
  }) {
    database.execute(write ? 'BEGIN IMMEDIATE' : 'BEGIN');
    try {
      final results = <List<SqlRow>>[];
      for (final statement in statements) {
        if (statement.returnsRows) {
          results.add([
            for (final row in database.select(
              statement.sql,
              statement.parameters,
            ))
              Map<String, Object?>.from(row),
          ]);
        } else {
          database.execute(statement.sql, statement.parameters);
          results.add(const []);
        }
      }
      database.execute('COMMIT');
      return results;
    } catch (error) {
      database.execute('ROLLBACK');
      if (error is SqliteException && error.message == 'rule_limit') {
        throw const StorageFailure(StorageFailureKind.capacity);
      }
      throw const StorageFailure(StorageFailureKind.unavailable);
    }
  }
}
