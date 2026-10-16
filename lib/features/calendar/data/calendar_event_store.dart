import 'dart:convert';
import 'dart:isolate';

import '../../../core/storage/local_database.dart';
import '../../../core/storage/storage_failure.dart';
import '../../../core/time/calendar_time.dart';
import '../domain/calendar_event.dart';
import '../domain/event_classifier.dart';
import 'calendar_cache_store.dart';
import 'ics_parser.dart';

class CalendarSourceState {
  const CalendarSourceState({
    this.syncedAt,
    this.failedAt,
    this.etag,
    this.lastModified,
  });
  final DateTime? syncedAt;
  final DateTime? failedAt;
  final String? etag;
  final String? lastModified;
  bool get isStale =>
      failedAt != null && (syncedAt == null || !failedAt!.isBefore(syncedAt!));
}

class CalendarReminderRecord {
  const CalendarReminderRecord({
    required this.uid,
    this.recurrenceId,
    required this.fireAt,
    required this.notificationId,
  });
  final String uid;
  final String? recurrenceId;
  final DateTime fireAt;
  final int notificationId;
}

/// Network history is kept separately from the user's stars and subscriptions.
class SqliteCalendarEventStore {
  SqliteCalendarEventStore(this._db);
  final LocalDatabase _db;
  Future<bool>? _migration;

  Future<bool> migrateLegacyCache() => _migration ??= _migrateLegacyCache();

  Future<bool> _migrateLegacyCache() async {
    final exists = (await _db.batch(const [
      SqlStatement(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='calendar_cache'",
        [],
        true,
      ),
    ])).single;
    if (exists.isEmpty) return false;
    final rows = (await _db.batch(const [
      SqlStatement('SELECT * FROM calendar_cache', [], true),
    ])).single;
    final statements = <SqlStatement>[];
    for (final row in rows) {
      final body = row['body'] as String;
      if (body.length > SqliteCalendarCacheStore.maxBodyCharacters) {
        throw const StorageFailure(StorageFailureKind.invalidData);
      }
      final source = Uri.parse(row['source'] as String);
      final at = DateTime.fromMillisecondsSinceEpoch(
        row['fetched_at'] as int,
        isUtc: true,
      );
      final existing = await readSource(source);
      if (existing?.syncedAt != null && !existing!.syncedAt!.isBefore(at)) {
        continue;
      }
      final events = await Isolate.run(() => IcsParser.parse(body));
      statements.addAll(_snapshotStatements(source, events, at));
      if (row['stale'] == 1) {
        statements.add(
          SqlStatement(
            "UPDATE calendar_sources SET failed_at=? WHERE calendar=? AND origin='ics'",
            [at.millisecondsSinceEpoch, source.toString()],
          ),
        );
      }
    }
    // Parsing and insertion must both succeed before the original cache goes.
    statements.add(const SqlStatement('DROP TABLE calendar_cache'));
    await _db.batch(statements, write: true);
    return rows.isNotEmpty;
  }

  Future<CalendarSourceState?> readSource(Uri calendar) async {
    final rows = (await _db.batch([
      SqlStatement(
        "SELECT * FROM calendar_sources WHERE calendar=? AND origin='ics'",
        [calendar.toString()],
        true,
      ),
    ])).single;
    if (rows.isEmpty) return null;
    final row = rows.single;
    return CalendarSourceState(
      syncedAt: _time(row['synced_at']),
      failedAt: _time(row['failed_at']),
      etag: row['etag'] as String?,
      lastModified: row['last_modified'] as String?,
    );
  }

  Future<List<CalendarEvent>> readEvents(
    Uri calendar, {
    DateTime? from,
    DateTime? until,
    bool includeGone = false,
  }) async {
    final rows = (await _db.batch([
      SqlStatement(
        '''SELECT * FROM calendar_events WHERE calendar=?
      ${includeGone ? '' : 'AND gone_at IS NULL'}
      ${from == null ? '' : 'AND end_ms>?'}
      ${until == null ? '' : 'AND start_ms<?'}
      ORDER BY start_ms,uid,recurrence_id''',
        [
          calendar.toString(),
          if (from != null) from.millisecondsSinceEpoch,
          if (until != null) until.millisecondsSinceEpoch,
        ],
        true,
      ),
    ])).single;
    return List.unmodifiable(rows.map(_event));
  }

  Future<void> writeSnapshot(
    Uri calendar,
    List<CalendarEvent> events,
    DateTime at, {
    String? etag,
    String? lastModified,
  }) async {
    await _db.batch(
      _snapshotStatements(
        calendar,
        events,
        at,
        etag: etag,
        lastModified: lastModified,
      ),
      write: true,
    );
  }

  List<SqlStatement> _snapshotStatements(
    Uri calendar,
    List<CalendarEvent> events,
    DateTime at, {
    String? etag,
    String? lastModified,
  }) {
    final key = calendar.toString();
    final ms = at.millisecondsSinceEpoch;
    return [
      SqlStatement(
        'UPDATE calendar_events SET gone_at=COALESCE(gone_at,?) WHERE calendar=? AND origin=\'ics\' AND end_ms>?',
        [ms, key, ms],
      ),
      for (final event in events) ...[
        SqlStatement(
          '''INSERT INTO calendar_events(calendar,uid,recurrence_id,sequence,status,all_day,start_ms,end_ms,start_date,end_date,title,description,location,url,categories,origin,first_seen,last_seen,gone_at)
          VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,'ics',?,?,NULL)
          ON CONFLICT(calendar,uid,recurrence_id) DO UPDATE SET
          sequence=excluded.sequence,status=excluded.status,all_day=excluded.all_day,
          start_ms=excluded.start_ms,end_ms=excluded.end_ms,start_date=excluded.start_date,end_date=excluded.end_date,
          title=excluded.title,description=excluded.description,location=excluded.location,url=excluded.url,categories=excluded.categories,
          origin=excluded.origin,last_seen=excluded.last_seen,gone_at=NULL
          WHERE excluded.sequence>=calendar_events.sequence AND excluded.last_seen>=calendar_events.last_seen''',
          [
            key,
            event.uid,
            event.recurrenceId ?? '',
            event.sequence,
            event.status.name,
            event.allDay ? 1 : 0,
            _instant(event.start, event.allDay),
            _instant(event.end, event.allDay),
            if (event.allDay) _date(event.start) else null,
            if (event.allDay) _date(event.end) else null,
            event.title,
            event.description,
            event.location,
            event.sourceUrl?.toString(),
            jsonEncode(event.categories),
            ms,
            ms,
          ],
        ),
        // Presence is observed even when an older source revision is rejected.
        SqlStatement(
          'UPDATE calendar_events SET last_seen=?,gone_at=NULL WHERE calendar=? AND uid=? AND recurrence_id=?',
          [ms, key, event.uid, event.recurrenceId ?? ''],
        ),
      ],
      SqlStatement(
        '''INSERT INTO calendar_sources(calendar,origin,url,etag,last_modified,synced_at) VALUES(?,'ics',?,?,?,?)
        ON CONFLICT(calendar,origin) DO UPDATE SET url=excluded.url,etag=excluded.etag,last_modified=excluded.last_modified,synced_at=excluded.synced_at,failed_at=NULL''',
        [key, key, etag, lastModified, ms],
      ),
    ];
  }

  Future<void> validated(
    Uri calendar,
    DateTime at, {
    String? etag,
    String? lastModified,
  }) async {
    await _db.batch([
      SqlStatement(
        "UPDATE calendar_sources SET synced_at=?,failed_at=NULL,etag=?,last_modified=? WHERE calendar=? AND origin='ics'",
        [at.millisecondsSinceEpoch, etag, lastModified, calendar.toString()],
      ),
    ], write: true);
  }

  Future<void> failed(Uri calendar, DateTime at) async {
    await _db.batch([
      SqlStatement(
        "INSERT INTO calendar_sources(calendar,origin,url,failed_at) VALUES(?,'ics',?,?) ON CONFLICT(calendar,origin) DO UPDATE SET failed_at=excluded.failed_at",
        [calendar.toString(), calendar.toString(), at.millisecondsSinceEpoch],
      ),
    ], write: true);
  }

  Future<Set<String>> readMemberFollows() async {
    final rows = (await _db.batch(const [
      SqlStatement(
        'SELECT member FROM calendar_member_follows ORDER BY followed_at,member',
        [],
        true,
      ),
    ])).single;
    return Set.unmodifiable(rows.map((row) => row['member'] as String));
  }

  Future<void> setMemberFollow(
    String member,
    bool followed, {
    DateTime? at,
  }) async {
    if (!EventClassifier.memberAliases.containsKey(member)) {
      throw const StorageFailure(StorageFailureKind.invalidData);
    }
    await _db.batch([
      followed
          ? SqlStatement(
              'INSERT INTO calendar_member_follows(member,followed_at) VALUES(?,?) ON CONFLICT DO NOTHING',
              [member, (at ?? DateTime.now()).millisecondsSinceEpoch],
            )
          : SqlStatement('DELETE FROM calendar_member_follows WHERE member=?', [
              member,
            ]),
    ], write: true);
  }

  Future<List<CalendarReminderRecord>> readReminders(Uri calendar) async {
    final rows = (await _db.batch([
      SqlStatement('SELECT * FROM calendar_reminders WHERE calendar=?', [
        calendar.toString(),
      ], true),
    ])).single;
    return rows
        .map(
          (row) => CalendarReminderRecord(
            uid: row['uid'] as String,
            recurrenceId: (row['recurrence_id'] as String).isEmpty
                ? null
                : row['recurrence_id'] as String,
            fireAt: _time(row['fire_at'])!,
            notificationId: row['notification_id'] as int,
          ),
        )
        .toList();
  }

  Future<void> replaceReminders(
    Uri calendar,
    List<CalendarReminderRecord> reminders,
  ) async {
    await _db.batch([
      SqlStatement('DELETE FROM calendar_reminders WHERE calendar=?', [
        calendar.toString(),
      ]),
      for (final reminder in reminders)
        SqlStatement(
          'INSERT INTO calendar_reminders(calendar,uid,recurrence_id,fire_at,notification_id) VALUES(?,?,?,?,?)',
          [
            calendar.toString(),
            reminder.uid,
            reminder.recurrenceId ?? '',
            reminder.fireAt.millisecondsSinceEpoch,
            reminder.notificationId,
          ],
        ),
    ], write: true);
  }

  static DateTime? _time(Object? ms) => ms == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(ms as int, isUtc: true);
  static String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  static int _instant(DateTime date, bool allDay) =>
      (allDay
              ? CalendarTime.wallTimeToUtc(date, CalendarTime.scheduleZone)
              : date)
          .millisecondsSinceEpoch;
  static CalendarEvent _event(SqlRow row) => CalendarEvent(
    uid: row['uid'] as String,
    recurrenceId: (row['recurrence_id'] as String).isEmpty
        ? null
        : row['recurrence_id'] as String,
    sequence: row['sequence'] as int,
    status: EventStatus.values.byName(row['status'] as String),
    allDay: row['all_day'] == 1,
    start: row['all_day'] == 1
        ? DateTime.parse('${row['start_date']}T00:00:00Z')
        : _time(row['start_ms'])!,
    end: row['all_day'] == 1
        ? DateTime.parse('${row['end_date']}T00:00:00Z')
        : _time(row['end_ms'])!,
    title: row['title'] as String,
    description: row['description'] as String,
    location: row['location'] as String,
    categories: (jsonDecode(row['categories'] as String) as List)
        .cast<String>(),
    sourceUrl: row['url'] == null ? null : Uri.parse(row['url'] as String),
  );
}
