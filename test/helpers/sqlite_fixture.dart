import 'package:asasfans_next/core/storage/local_database.dart';
import 'package:asasfans_next/core/storage/storage_failure.dart';
import 'package:sqlite3/sqlite3.dart';

/// Test-only downgrade of a disposable fixture, never an application database.
void removeSubscriptionV5Fixture(Database database) {
  for (final op in ['insert', 'update', 'delete']) {
    database.execute('DROP TRIGGER subscription_roster_$op');
  }
  database.execute('DROP TABLE subscription_reads');
  database.execute('DROP TABLE subscription_meta');
  database.userVersion = 4;
}

/// Real SQL semantics with a disposable connection, never the app directory.
class MemoryLocalDatabase implements LocalDatabase {
  MemoryLocalDatabase() : database = sqlite3.openInMemory() {
    SqliteExecutor.initialize(database);
  }
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
