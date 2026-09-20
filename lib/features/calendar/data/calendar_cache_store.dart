import '../../../core/storage/local_database.dart';
import '../../../core/storage/storage_failure.dart';

class CalendarCacheEntry {
  const CalendarCacheEntry({
    required this.body,
    required this.fetchedAt,
    this.etag,
    this.lastModified,
    this.stale = false,
  });
  final String body;
  final DateTime fetchedAt;
  final String? etag;
  final String? lastModified;
  final bool stale;
}

abstract interface class CalendarCacheStore {
  Future<CalendarCacheEntry?> read(Uri source);
  Future<void> write(Uri source, CalendarCacheEntry entry);
  Future<void> remove(Uri source);
}

class SqliteCalendarCacheStore implements CalendarCacheStore {
  SqliteCalendarCacheStore(this._database);
  final LocalDatabase _database;
  // Bounds persisted source data; this is not a limit on the user's assets.
  static const maxBodyCharacters = 4 * 1024 * 1024;
  static const maxSources = 8;

  @override
  Future<CalendarCacheEntry?> read(Uri source) async {
    final rows = (await _database.batch([
      SqlStatement(
        'SELECT body, fetched_at, etag, last_modified, stale FROM calendar_cache WHERE source = ?',
        [source.toString()],
        true,
      ),
    ])).single;
    if (rows.isEmpty) return null;
    final row = rows.single;
    final body = row['body'];
    final fetchedAt = row['fetched_at'];
    if (body is! String ||
        body.length > maxBodyCharacters ||
        fetchedAt is! int ||
        fetchedAt < 0 ||
        fetchedAt > 8640000000000000) {
      throw const StorageFailure(StorageFailureKind.invalidData);
    }
    return CalendarCacheEntry(
      body: body,
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(fetchedAt, isUtc: true),
      etag: _header(row['etag']),
      lastModified: _header(row['last_modified']),
      stale: row['stale'] == 1,
    );
  }

  @override
  Future<void> write(Uri source, CalendarCacheEntry entry) async {
    if (entry.body.length > maxBodyCharacters ||
        entry.fetchedAt.millisecondsSinceEpoch < 0) {
      throw const StorageFailure(StorageFailureKind.invalidData);
    }
    await _database.batch([
      SqlStatement(
        '''INSERT INTO calendar_cache(source, body, fetched_at, etag, last_modified, stale) VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(source) DO UPDATE SET body = excluded.body, fetched_at = excluded.fetched_at,
        etag = excluded.etag, last_modified = excluded.last_modified, stale = excluded.stale''',
        [
          source.toString(),
          entry.body,
          entry.fetchedAt.millisecondsSinceEpoch,
          _header(entry.etag),
          _header(entry.lastModified),
          entry.stale ? 1 : 0,
        ],
      ),
      const SqlStatement(
        'DELETE FROM calendar_cache WHERE source NOT IN (SELECT source FROM calendar_cache ORDER BY fetched_at DESC, source LIMIT $maxSources)',
      ),
    ], write: true);
  }

  @override
  Future<void> remove(Uri source) async {
    await _database.batch([
      SqlStatement('DELETE FROM calendar_cache WHERE source = ?', [
        source.toString(),
      ]),
    ], write: true);
  }

  static String? _header(Object? value) =>
      value is String &&
          value.length <= 4096 &&
          !value.contains(RegExp(r'[\r\n]'))
      ? value
      : null;
}
