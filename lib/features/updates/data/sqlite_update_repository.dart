import 'dart:async';

import '../../../core/domain/content_identity.dart';
import '../../../core/storage/local_database.dart';
import '../../../core/storage/storage_failure.dart';
import '../../library/data/library_codec.dart';
import '../../library/domain/library_models.dart';
import '../../library/domain/library_page.dart';
import '../domain/update_event.dart';
import '../domain/update_repository.dart';

class SqliteUpdateRepository implements UpdateRepository {
  SqliteUpdateRepository(this._db);
  final LocalDatabase _db;
  final _changes = StreamController<int>.broadcast();
  int _revision = 0;
  bool _closed = false;

  @override
  Stream<int> get changes => _changes.stream;

  @override
  Future<void> close() async {
    if (!_closed) {
      _closed = true;
      await _changes.close();
    }
  }

  Future<SqlResults> _batch(
    List<SqlStatement> statements, {
    bool write = false,
  }) {
    if (_closed) throw const StorageFailure(StorageFailureKind.closed);
    return _db.batch(statements, write: write);
  }

  void _notify() {
    if (!_closed) _changes.add(++_revision);
  }

  static int _epoch(DateTime value) {
    final ms = value.toUtc().millisecondsSinceEpoch;
    if (ms < 0) throw const StorageFailure(StorageFailureKind.invalidData);
    return ms;
  }

  static DateTime _time(Object? raw) =>
      DateTime.fromMillisecondsSinceEpoch(raw as int, isUtc: true);

  /// One harvest is one transaction.
  ///
  /// Cursors advance in the same statement list as the events they produced. If
  /// the write fails, both roll back and the next pass re-reads the same range:
  /// re-reading costs a request, while a cursor that moved without its events
  /// would silently skip them forever.
  @override
  Future<void> commit(UpdateHarvest harvest) async {
    if (harvest.events.isEmpty && harvest.cursors.isEmpty) return;
    final commands = <SqlStatement>[
      for (final event in harvest.events) _insert(event),
      for (final cursor in harvest.cursors.values) _cursor(cursor),
    ];
    await _batch(commands, write: true);
    _notify();
  }

  /// A re-observed event keeps the row the user already acted on.
  ///
  /// Only the source-owned description may be refreshed. `is_read` and
  /// `archived_at` are deliberately absent from the update clause: a second
  /// poll must never turn a dealt-with entry back into an unread one, and
  /// `observed_at` keeps naming the first sighting.
  static SqlStatement _insert(UpdateEvent event) {
    if (event.id.isEmpty || event.id.length > 512) {
      throw const StorageFailure(StorageFailureKind.invalidData);
    }
    final content = event.content;
    final follow = event.followKey;
    if ((event.kind == UpdateKind.subscriptionVideo) != (content != null) ||
        (event.kind == UpdateKind.scheduleChange) !=
            (follow != null && event.scheduleChange != null)) {
      throw const StorageFailure(StorageFailureKind.invalidData);
    }
    if (follow != null && LibraryCodec.publicUri(follow.source) == null) {
      throw const StorageFailure(StorageFailureKind.invalidData);
    }
    return SqlStatement(
      '''INSERT INTO update_events(
        id,kind,title,subtitle,occurred_at,observed_at,
        source,content_id,creator_mid,creator_name,
        follow_source,follow_uid,follow_recurrence_id,schedule_change)
      VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)
      ON CONFLICT(id) DO UPDATE SET
        title=excluded.title,subtitle=excluded.subtitle,
        occurred_at=excluded.occurred_at''',
      [
        event.id,
        event.kind.name,
        LibraryCodec.id(event.title),
        _subtitle(event.subtitle),
        _epoch(event.occurredAt),
        _epoch(event.observedAt),
        content?.source.name,
        content == null ? null : LibraryCodec.id(content.value),
        event.creator?.mid,
        event.creator == null ? null : LibraryCodec.id(event.creator!.name),
        follow?.source.toString(),
        follow == null ? null : LibraryCodec.id(follow.uid),
        follow?.recurrenceId ?? (follow == null ? null : ''),
        event.scheduleChange?.name,
      ],
    );
  }

  static String _subtitle(String value) {
    if (value.length > 1000 || value.contains('\u0000')) {
      throw const StorageFailure(StorageFailureKind.invalidData);
    }
    return value;
  }

  /// A cursor only ever moves forward. The SQL repeats the comparison so a
  /// concurrent pass that already advanced further is not rewound by a slower
  /// one committing afterwards.
  static SqlStatement _cursor(UpdateCursor cursor) => SqlStatement(
    '''INSERT INTO update_cursors(source_key,baseline_at,last_occurred_at,last_id)
    VALUES(?,?,?,?)
    ON CONFLICT(source_key) DO UPDATE SET
      last_occurred_at=excluded.last_occurred_at,last_id=excluded.last_id
    WHERE excluded.last_occurred_at IS NOT NULL
      AND (update_cursors.last_occurred_at IS NULL
        OR excluded.last_occurred_at > update_cursors.last_occurred_at
        OR (excluded.last_occurred_at = update_cursors.last_occurred_at
          AND excluded.last_id > update_cursors.last_id))''',
    [
      LibraryCodec.id(cursor.sourceKey),
      _epoch(cursor.baselineAt),
      cursor.lastOccurredAt == null ? null : _epoch(cursor.lastOccurredAt!),
      cursor.lastId,
    ],
  );

  @override
  Future<Map<String, UpdateCursor>> cursors() async {
    final rows = (await _batch([
      const SqlStatement('SELECT * FROM update_cursors', [], true),
    ])).single;
    return {
      for (final row in rows)
        row['source_key'] as String: UpdateCursor(
          sourceKey: row['source_key'] as String,
          baselineAt: _time(row['baseline_at']),
          lastOccurredAt: row['last_occurred_at'] == null
              ? null
              : _time(row['last_occurred_at']),
          lastId: row['last_id'] as String?,
        ),
    };
  }

  @override
  Future<UpdateCounts> counts() async {
    final row = (await _batch([
      const SqlStatement(
        '''SELECT
          COUNT(*) FILTER (WHERE archived_at=0 AND is_read=0) AS unread,
          COUNT(*) FILTER (WHERE archived_at=0) AS inbox
        FROM update_events''',
        [],
        true,
      ),
    ])).single.single;
    return UpdateCounts(
      unread: row['unread'] as int,
      inbox: row['inbox'] as int,
    );
  }

  @override
  Future<LibraryPage<UpdateEvent>> page({
    required UpdateFilter filter,
    LibraryCursor? cursor,
    int limit = 40,
  }) async {
    // Archived entries sort by when the user filed them; everything else sorts
    // by when it happened at the source.
    final (where, order) = switch (filter) {
      UpdateFilter.inbox => ('archived_at=0', ['-occurred_at', 'id']),
      UpdateFilter.unread => (
        'archived_at=0 AND is_read=0',
        ['-occurred_at', 'id'],
      ),
      UpdateFilter.archived => ('archived_at>0', ['-archived_at', 'id']),
    };
    if (limit < 1 ||
        limit > 100 ||
        (cursor != null &&
            (cursor.query != filter ||
                cursor.key.length != order.length ||
                cursor.key.first is! int ||
                cursor.key.last is! String))) {
      throw const StorageFailure(StorageFailureKind.invalidData);
    }
    final result = await _batch([
      const SqlStatement(
        'SELECT store_id,revision FROM library_meta WHERE singleton=1',
        [],
        true,
      ),
      SqlStatement(
        'SELECT *,${order.indexed.map((e) => '${e.$2} AS _k${e.$1}').join(',')} '
        'FROM update_events WHERE ($where) '
        '${cursor == null ? '' : 'AND (${order.join(',')}) > (?,?)'} '
        'ORDER BY ${order.join(',')} LIMIT ?',
        [if (cursor != null) ...cursor.key, limit + 1],
        true,
      ),
    ]);
    final meta = result[0].single;
    if (cursor != null &&
        (cursor.storeId != meta['store_id'] ||
            cursor.revision != meta['revision'])) {
      throw const StorageFailure(StorageFailureKind.changed);
    }
    final rows = result[1].take(limit).toList();
    return LibraryPage(
      items: [for (final row in rows) _event(row)],
      next: result[1].length <= limit
          ? null
          : LibraryCursor(
              storeId: meta['store_id'] as String,
              revision: meta['revision'] as int,
              query: filter,
              key: [rows.last['_k0'], rows.last['_k1']],
            ),
    );
  }

  static UpdateEvent _event(SqlRow row) {
    final kind = UpdateKind.values
        .where((value) => value.name == row['kind'])
        .firstOrNull;
    if (kind == null) {
      throw const StorageFailure(StorageFailureKind.invalidData);
    }
    final source = ContentSource.values
        .where((value) => value.name == row['source'])
        .firstOrNull;
    final contentId = row['content_id'];
    final followSource = LibraryCodec.publicUri(row['follow_source']);
    final followUid = row['follow_uid'];
    final mid = row['creator_mid'];
    final recurrence = row['follow_recurrence_id'] as String?;
    return UpdateEvent(
      id: row['id'] as String,
      kind: kind,
      title: row['title'] as String,
      subtitle: row['subtitle'] as String,
      occurredAt: _time(row['occurred_at']),
      observedAt: _time(row['observed_at']),
      content: source == null || contentId is! String
          ? null
          : ContentIdentity(source: source, value: contentId),
      creator: mid is String && LocalSubscription.validMid(mid)
          ? LocalSubscription(
              mid: mid,
              name: row['creator_name'] as String? ?? '',
            )
          : null,
      followKey: followSource == null || followUid is! String
          ? null
          : CalendarFollowKey(
              source: followSource,
              uid: followUid,
              // An empty column is the stored form of "no recurrence id"; it is
              // not a recurrence whose id happens to be the empty string.
              recurrenceId: recurrence == null || recurrence.isEmpty
                  ? null
                  : recurrence,
            ),
      scheduleChange: ScheduleChange.values
          .where((value) => value.name == row['schedule_change'])
          .firstOrNull,
      read: row['is_read'] == 1,
      archived: (row['archived_at'] as int) > 0,
    );
  }

  @override
  Future<void> markRead(Iterable<String> ids, {required bool read}) =>
      _update(ids, 'is_read=?', [read ? 1 : 0]);

  @override
  Future<void> archive(Iterable<String> ids, {required bool archived}) =>
      _update(ids, 'archived_at=?', [
        archived ? DateTime.now().toUtc().millisecondsSinceEpoch : 0,
      ]);

  Future<void> _update(
    Iterable<String> ids,
    String set,
    List<Object?> values,
  ) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return;
    // Chunked so a large selection cannot exceed SQLite's variable limit.
    final commands = <SqlStatement>[];
    for (var start = 0; start < list.length; start += 200) {
      final chunk = list.sublist(
        start,
        start + 200 > list.length ? list.length : start + 200,
      );
      commands.add(
        SqlStatement(
          'UPDATE update_events SET $set WHERE id IN (${List.filled(chunk.length, '?').join(',')})',
          [...values, ...chunk],
        ),
      );
    }
    await _batch(commands, write: true);
    _notify();
  }

  /// Archived entries stay as they are: the user already dealt with them, and
  /// a bulk read action is about clearing what is still waiting.
  @override
  Future<void> markAllRead() async {
    await _batch([
      const SqlStatement(
        'UPDATE update_events SET is_read=1 WHERE is_read=0 AND archived_at=0',
      ),
    ], write: true);
    _notify();
  }
}
