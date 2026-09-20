import '../domain/library_repository.dart';
import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import '../../../core/domain/content_identity.dart';
import '../../../core/storage/local_database.dart';
import '../../../core/storage/storage_failure.dart';
import '../../calendar/domain/calendar_event.dart';
import '../domain/library_models.dart';
import '../domain/library_page.dart';
import 'library_codec.dart';

class SqliteLibraryRepository implements LibraryRepository {
  SqliteLibraryRepository(
    this._db, {
    DateTime Function()? clock,
    this.backgroundDecoding = true,
  }) : _clock = clock ?? DateTime.now;
  final LocalDatabase _db;
  final bool backgroundDecoding;
  final DateTime Function() _clock;
  final _changes = StreamController<int>.broadcast();
  final _subscriptionChanges = StreamController<int>.broadcast();
  int _revision = 0;
  bool _closed = false;
  int get _now => _clock().toUtc().millisecondsSinceEpoch;
  @override
  Stream<int> get changes => _changes.stream;
  @override
  Stream<int> get subscriptionChanges => _subscriptionChanges.stream;
  void _notify() {
    if (!_closed) _changes.add(++_revision);
  }

  @override
  void notifyExternalCommit() {
    _notify();
    if (!_closed) _subscriptionChanges.add(_revision);
  }

  @override
  Future<void> close() async {
    if (!_closed) {
      _closed = true;
      await _changes.close();
      await _subscriptionChanges.close();
    }
  }

  Future<SqlResults> _batch(
    List<SqlStatement> statements, {
    bool write = false,
  }) {
    if (_closed) throw const StorageFailure(StorageFailureKind.closed);
    return _db.batch(statements, write: write);
  }

  static List<Object?> _identity(ContentIdentity id) => [
    id.source.name,
    LibraryCodec.id(id.value),
  ];
  static List<Object?> _key(CalendarFollowKey key) => [
    key.source.toString(),
    LibraryCodec.id(key.uid),
    key.recurrenceId ?? '',
  ];

  /// Local-only identifier for a user-created row. It is never a source id and
  /// never leaves this store.
  static String _localId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static String _folderName(String name) {
    final value = name.trim();
    if (value.isEmpty || value.length > 64 || value.contains('\u0000')) {
      throw const StorageFailure(StorageFailureKind.invalidData);
    }
    return value;
  }

  SqlStatement _content(ContentSnapshot item) => SqlStatement(
    '''INSERT INTO content_refs(source,content_id,snapshot,updated_at) VALUES(?,?,?,?)
    ON CONFLICT(source,content_id) DO UPDATE SET snapshot=excluded.snapshot,updated_at=excluded.updated_at
    WHERE excluded.updated_at >= content_refs.updated_at''',
    [..._identity(item.identity), LibraryCodec.encodeContent(item), _now],
  );
  // subscription_reads owns only a BVID receipt, not a content_refs snapshot.
  // Its lifetime is independent of this pruning and of unsubscription.
  //
  // Playback progress and bookmarks do own snapshots: a resume entry or a
  // bookmark must keep its title after the item leaves every folder, watch-later
  // and history list, so both are reference holders here.
  static const _prune = SqlStatement(
    '''DELETE FROM content_refs AS c
    WHERE NOT EXISTS(SELECT 1 FROM collection_items s WHERE s.source=c.source AND s.content_id=c.content_id)
    AND NOT EXISTS(SELECT 1 FROM watch_later w WHERE w.source=c.source AND w.content_id=c.content_id)
    AND NOT EXISTS(SELECT 1 FROM content_history h WHERE h.source=c.source AND h.content_id=c.content_id)
    AND NOT EXISTS(SELECT 1 FROM playback_progress p WHERE p.source=c.source AND p.content_id=c.content_id)
    AND NOT EXISTS(SELECT 1 FROM playback_bookmarks b WHERE b.source=c.source AND b.content_id=c.content_id)''',
  );
  Future<void> _write(
    List<SqlStatement> commands, {
    bool subscriptions = false,
  }) async {
    await _batch(commands, write: true);
    _notify();
    if (subscriptions && !_closed) _subscriptionChanges.add(_revision);
  }

  Future<LibraryPage<T>> _page<T>({
    required Object query,
    required String select,
    required String from,
    required List<String> order,
    required T Function(SqlRow) decode,
    String where = '1',
    List<Object?> parameters = const [],
    LibraryCursor? cursor,
    int limit = 40,
    int numericKeys = 1,
  }) async {
    if (limit < 1 ||
        limit > 100 ||
        (cursor != null &&
            (cursor.query != query ||
                cursor.key.length != order.length ||
                cursor.key.indexed.any(
                  (entry) => entry.$1 < numericKeys
                      ? entry.$2 is! int
                      : entry.$2 is! String,
                )))) {
      throw const StorageFailure(StorageFailureKind.invalidData);
    }
    final result = await _batch([
      const SqlStatement(
        'SELECT store_id,revision FROM library_meta WHERE singleton=1',
        [],
        true,
      ),
      SqlStatement(
        'SELECT $select,${order.indexed.map((e) => '${e.$2} AS _k${e.$1}').join(',')} '
        'FROM $from WHERE ($where) '
        '${cursor == null ? '' : 'AND (${order.join(',')}) > (${List.filled(order.length, '?').join(',')})'} '
        'ORDER BY ${order.join(',')} LIMIT ?',
        [...parameters, if (cursor != null) ...cursor.key, limit + 1],
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
      items: backgroundDecoding
          ? await _decodeRows(rows, decode)
          : rows.map(decode).toList(),
      next: result[1].length <= limit
          ? null
          : LibraryCursor(
              storeId: meta['store_id'] as String,
              revision: meta['revision'] as int,
              query: query,
              key: List.generate(order.length, (i) => rows.last['_k$i']),
            ),
    );
  }

  @override
  Future<LibraryPage<CollectionFolder>> folderPage({
    LibraryCursor? cursor,
    int limit = 40,
  }) => _page(
    query: 'folders',
    select:
        'f.id,f.name,(SELECT COUNT(*) FROM collection_items i WHERE i.folder_id=f.id) AS count',
    from: 'collection_folders f',
    order: ['f.created_at', 'f.id'],
    decode: _folder,
    cursor: cursor,
    limit: limit,
  );

  @override
  Future<LibraryPage<LibraryRecord>> recordPage(
    LibraryQuery query, {
    LibraryCursor? cursor,
    int limit = 40,
  }) {
    final (table, select, order, where, params) = switch (query.kind) {
      LibraryListKind.collection => (
        'collection_items',
        'i.added_at AS at',
        ['-i.added_at', 'i.source', 'i.content_id'],
        'i.folder_id=?',
        <Object?>[query.folderId],
      ),
      LibraryListKind.later => (
        'watch_later',
        'i.added_at AS at,i.done',
        ['i.done', '-i.added_at', 'i.source', 'i.content_id'],
        query.pendingOnly ? 'i.done=0' : '1',
        <Object?>[],
      ),
      LibraryListKind.history => (
        'content_history',
        'i.last_at AS at,i.action,i.visits',
        ['-i.last_at', 'i.source', 'i.content_id', 'i.action'],
        query.action == null ? '1' : 'i.action=?',
        <Object?>[if (query.action != null) query.action!.name],
      ),
    };
    return _page(
      query: query,
      select: 'c.source,c.content_id,c.snapshot,$select',
      from:
          '$table i JOIN content_refs c ON c.source=i.source AND c.content_id=i.content_id',
      order: order,
      where: where,
      parameters: params,
      decode: _record,
      numericKeys: query.kind == LibraryListKind.later ? 2 : 1,
      cursor: cursor,
      limit: limit,
    );
  }

  @override
  Future<LibraryPage<LocalSubscription>> subscriptionPage({
    LibraryCursor? cursor,
    int limit = 40,
  }) => _page(
    query: 'subscriptions',
    select: 'i.mid,i.name,i.avatar',
    from: 'local_subscriptions i',
    order: ['-i.added_at', 'i.mid'],
    decode: _subscription,
    cursor: cursor,
    limit: limit,
  );

  @override
  Future<LibraryPage<CalendarFollow>> calendarFollowPage({
    LibraryCursor? cursor,
    int limit = 40,
  }) => _page(
    query: 'follows',
    select: 'i.*',
    from: 'calendar_follows i',
    order: ['-i.followed_at', 'i.source', 'i.uid', 'i.recurrence_id'],
    decode: _follow,
    cursor: cursor,
    limit: limit,
  );

  @override
  Future<bool> isSubscribed(String mid) async => (await _batch([
    SqlStatement('SELECT 1 FROM local_subscriptions WHERE mid=?', [mid], true),
  ])).single.isNotEmpty;

  @override
  Future<bool> isFollowingCalendar(
    CalendarFollowKey key,
  ) async => (await _batch([
    SqlStatement(
      'SELECT 1 FROM calendar_follows WHERE source=? AND uid=? AND recurrence_id=?',
      _key(key),
      true,
    ),
  ])).single.isNotEmpty;

  static CollectionFolder _folder(SqlRow row) => CollectionFolder(
    id: row['id'] as String,
    name: row['name'] as String,
    count: row['count'] as int,
  );
  static LocalSubscription _subscription(SqlRow row) => LocalSubscription(
    mid: row['mid'] as String,
    name: row['name'] as String,
    avatar: LibraryCodec.publicUri(row['avatar']),
  );

  @override
  Future<CollectionFolder?> folder(String id) async {
    final rows = (await _batch([
      SqlStatement(
        'SELECT f.id,f.name,(SELECT COUNT(*) FROM collection_items i WHERE i.folder_id=f.id) AS count FROM collection_folders f WHERE f.id=?',
        [id],
        true,
      ),
    ])).single;
    return rows.isEmpty ? null : _folder(rows.single);
  }

  @override
  Future<List<CollectionFolder>> folders() async {
    final rows = (await _batch([
      const SqlStatement(
        '''SELECT f.id,f.name,COUNT(i.content_id) AS count FROM collection_folders f
      LEFT JOIN collection_items i ON i.folder_id=f.id GROUP BY f.id ORDER BY f.created_at,f.id''',
        [],
        true,
      ),
    ])).single;
    return [
      for (final row in rows)
        CollectionFolder(
          id: row['id'] as String,
          name: row['name'] as String,
          count: row['count'] as int,
        ),
    ];
  }

  @override
  Future<String> createFolder(String name) async {
    final id = _localId();
    await _write([
      SqlStatement('INSERT INTO collection_folders VALUES(?,?,?)', [
        id,
        _folderName(name),
        _now,
      ]),
    ]);
    return id;
  }

  @override
  Future<void> renameFolder(String id, String name) async {
    if (id == 'default') {
      throw const StorageFailure(StorageFailureKind.invalidData);
    }
    await _write([
      SqlStatement('UPDATE collection_folders SET name=? WHERE id=?', [
        _folderName(name),
        id,
      ]),
    ]);
  }

  @override
  Future<void> deleteFolder(String id) async {
    if (id == 'default') {
      throw const StorageFailure(StorageFailureKind.invalidData);
    }
    await _write([
      SqlStatement('DELETE FROM collection_folders WHERE id=?', [id]),
      _prune,
    ]);
  }

  @override
  Future<LibraryItemState> itemState(ContentIdentity identity) async {
    final result = await _batch([
      SqlStatement(
        'SELECT folder_id FROM collection_items WHERE source=? AND content_id=?',
        _identity(identity),
        true,
      ),
      SqlStatement(
        'SELECT done FROM watch_later WHERE source=? AND content_id=?',
        _identity(identity),
        true,
      ),
    ]);
    return LibraryItemState(
      folderIds: Set.unmodifiable(
        result[0].map((row) => row['folder_id'] as String),
      ),
      later: result[1].isNotEmpty,
      laterDone: result[1].firstOrNull?['done'] == 1,
    );
  }

  @override
  Future<void> setCollected(
    ContentSnapshot item,
    String folderId,
    bool collected,
  ) => _write(
    collected
        ? [
            _content(item),
            SqlStatement(
              'INSERT INTO collection_items VALUES(?,?,?,?) ON CONFLICT DO NOTHING',
              [folderId, ..._identity(item.identity), _now],
            ),
          ]
        : [
            SqlStatement(
              'DELETE FROM collection_items WHERE folder_id=? AND source=? AND content_id=?',
              [folderId, ..._identity(item.identity)],
            ),
            _prune,
          ],
  );
  @override
  Future<List<LibraryRecord>> collection(String folderId) => _records(
    '''SELECT c.source,c.content_id,c.snapshot,i.added_at AS at FROM collection_items i
    JOIN content_refs c ON c.source=i.source AND c.content_id=i.content_id WHERE i.folder_id=? ORDER BY i.added_at DESC,c.source,c.content_id''',
    [folderId],
  );
  @override
  Future<void> setLater(ContentSnapshot item, bool saved) => _write(
    saved
        ? [
            _content(item),
            SqlStatement(
              'INSERT INTO watch_later VALUES(?,?,?,0) ON CONFLICT(source,content_id) DO NOTHING',
              [..._identity(item.identity), _now],
            ),
          ]
        : [
            SqlStatement(
              'DELETE FROM watch_later WHERE source=? AND content_id=?',
              _identity(item.identity),
            ),
            _prune,
          ],
  );
  @override
  Future<void> setLaterDone(ContentIdentity identity, bool done) => _write([
    SqlStatement(
      'UPDATE watch_later SET done=? WHERE source=? AND content_id=?',
      [done ? 1 : 0, ..._identity(identity)],
    ),
  ]);
  @override
  Future<List<LibraryRecord>> later() => _records(
    '''SELECT c.source,c.content_id,c.snapshot,w.added_at AS at,w.done FROM watch_later w
    JOIN content_refs c ON c.source=w.source AND c.content_id=w.content_id ORDER BY w.done,w.added_at DESC,c.source,c.content_id''',
    [],
  );
  @override
  Future<void> recordHistory(
    ContentSnapshot item,
    HistoryAction action,
  ) => _write([
    _content(item),
    SqlStatement(
      '''INSERT INTO content_history(source,content_id,action,last_at,visits) VALUES(?,?,?,?,1)
      ON CONFLICT(source,content_id,action) DO UPDATE SET last_at=MAX(content_history.last_at,excluded.last_at),visits=content_history.visits+1''',
      [..._identity(item.identity), action.name, _now],
    ),
  ]);
  @override
  Future<List<LibraryRecord>> history({HistoryAction? action}) => _records(
    '''SELECT c.source,c.content_id,c.snapshot,h.last_at AS at,h.action,h.visits FROM content_history h
    JOIN content_refs c ON c.source=h.source AND c.content_id=h.content_id ${action == null ? '' : 'WHERE h.action=?'} ORDER BY h.last_at DESC,c.source,c.content_id,h.action''',
    [if (action != null) action.name],
  );
  @override
  Future<void> removeHistory(
    ContentIdentity identity,
    HistoryAction action,
  ) => _write([
    SqlStatement(
      'DELETE FROM content_history WHERE source=? AND content_id=? AND action=?',
      [..._identity(identity), action.name],
    ),
    _prune,
  ]);
  @override
  Future<void> clearHistory({HistoryAction? action}) => _write([
    SqlStatement(
      'DELETE FROM content_history ${action == null ? '' : 'WHERE action=?'}',
      [if (action != null) action.name],
    ),
    _prune,
  ]);
  Future<List<LibraryRecord>> _records(String sql, List<Object?> params) async {
    final rows = (await _batch([SqlStatement(sql, params, true)])).single;
    return [for (final row in rows) _record(row)];
  }

  static LibraryRecord _record(SqlRow row) {
    final item = LibraryCodec.decodeContent(row['snapshot'] as String);
    if (item.identity.source.name != row['source'] ||
        item.identity.value != row['content_id']) {
      throw const StorageFailure(StorageFailureKind.invalidData);
    }
    return LibraryRecord(
      item: item,
      at: DateTime.fromMillisecondsSinceEpoch(row['at'] as int, isUtc: true),
      action: row['action'] == null
          ? null
          : HistoryAction.values.byName(row['action'] as String),
      visits: row['visits'] as int? ?? 1,
      done: row['done'] == 1,
    );
  }

  static List<Object?> _part(PlaybackPart part) => [
    ..._identity(part.identity),
    LibraryCodec.id(part.partId),
  ];

  /// Milliseconds must stay inside a range SQLite stores exactly and that no
  /// real media can exceed, so a malformed duration cannot poison a row.
  static int _millis(Duration value) {
    final ms = value.inMilliseconds;
    if (ms < 0 || ms > _maxMillis) {
      throw const StorageFailure(StorageFailureKind.invalidData);
    }
    return ms;
  }

  static const _maxMillis = 1000 * 60 * 60 * 24 * 30;

  static String _bookmarkText(String value, int limit) {
    if (value.length > limit || value.contains('\u0000')) {
      throw const StorageFailure(StorageFailureKind.invalidData);
    }
    return value;
  }

  static PlaybackProgress _progress(SqlRow row) => PlaybackProgress(
    part: PlaybackPart(
      identity: ContentIdentity(
        source: ContentSource.values.byName(row['source'] as String),
        value: row['content_id'] as String,
      ),
      partId: row['part_id'] as String,
    ),
    position: Duration(milliseconds: row['position_ms'] as int),
    duration: Duration(milliseconds: row['duration_ms'] as int),
    completed: row['completed'] == 1,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      row['updated_at'] as int,
      isUtc: true,
    ),
  );

  static PlaybackBookmark _bookmark(SqlRow row) => PlaybackBookmark(
    id: row['id'] as String,
    part: PlaybackPart(
      identity: ContentIdentity(
        source: ContentSource.values.byName(row['source'] as String),
        value: row['content_id'] as String,
      ),
      partId: row['part_id'] as String,
    ),
    start: Duration(milliseconds: row['start_ms'] as int),
    end: row['end_ms'] == null
        ? null
        : Duration(milliseconds: row['end_ms'] as int),
    title: row['title'] as String,
    note: row['note'] as String? ?? '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      row['created_at'] as int,
      isUtc: true,
    ),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      row['updated_at'] as int,
      isUtc: true,
    ),
  );

  /// Verifies the joined snapshot really describes the row's own item, the same
  /// check [_record] performs, so a corrupted snapshot cannot be shown under
  /// another item's identity.
  static ContentSnapshot _joined(SqlRow row) {
    final item = LibraryCodec.decodeContent(row['snapshot'] as String);
    if (item.identity.source.name != row['source'] ||
        item.identity.value != row['content_id']) {
      throw const StorageFailure(StorageFailureKind.invalidData);
    }
    return item;
  }

  @override
  Future<LibraryPage<PlaybackRecord>> progressPage({
    bool unfinishedOnly = true,
    LibraryCursor? cursor,
    int limit = 40,
  }) => _page(
    query: 'progress:$unfinishedOnly',
    select:
        'p.source,p.content_id,p.part_id,p.position_ms,p.duration_ms,p.completed,p.updated_at,c.snapshot',
    from:
        'playback_progress p JOIN content_refs c ON c.source=p.source AND c.content_id=p.content_id',
    where: unfinishedOnly ? 'p.completed=0' : '1',
    order: ['-p.updated_at', 'p.source', 'p.content_id', 'p.part_id'],
    decode: (row) =>
        PlaybackRecord(item: _joined(row), progress: _progress(row)),
    cursor: cursor,
    limit: limit,
  );

  @override
  Future<LibraryPage<BookmarkRecord>> bookmarkPage({
    LibraryCursor? cursor,
    int limit = 40,
  }) => _page(
    query: 'bookmarks',
    select:
        'b.id,b.source,b.content_id,b.part_id,b.start_ms,b.end_ms,b.title,b.note,b.created_at,b.updated_at,c.snapshot',
    from:
        'playback_bookmarks b JOIN content_refs c ON c.source=b.source AND c.content_id=b.content_id',
    order: ['-b.created_at', 'b.id'],
    decode: (row) =>
        BookmarkRecord(item: _joined(row), bookmark: _bookmark(row)),
    cursor: cursor,
    limit: limit,
  );

  @override
  Future<PlaybackProgress?> progress(PlaybackPart part) async {
    final rows = (await _batch([
      SqlStatement(
        'SELECT source,content_id,part_id,position_ms,duration_ms,completed,updated_at '
        'FROM playback_progress WHERE source=? AND content_id=? AND part_id=?',
        _part(part),
        true,
      ),
    ])).single;
    return rows.isEmpty ? null : _progress(rows.single);
  }

  @override
  Future<Map<String, PlaybackProgress>> contentProgress(
    ContentIdentity identity,
  ) async {
    final rows = (await _batch([
      SqlStatement(
        'SELECT source,content_id,part_id,position_ms,duration_ms,completed,updated_at '
        'FROM playback_progress WHERE source=? AND content_id=? ORDER BY part_id',
        _identity(identity),
        true,
      ),
    ])).single;
    return Map.unmodifiable({
      for (final row in rows) row['part_id'] as String: _progress(row),
    });
  }

  @override
  Future<void> saveProgress(
    ContentSnapshot item,
    String partId,
    Duration position, {
    Duration duration = Duration.zero,
    bool? completed,
  }) async {
    final positionMs = _millis(position);
    final durationMs = _millis(duration);
    // A known duration bounds the position: a late report from a longer source
    // must not store a position past the end of the part being watched.
    final bounded = durationMs == 0
        ? positionMs
        : positionMs > durationMs
        ? durationMs
        : positionMs;
    final finished =
        completed ??
        (durationMs > 0 &&
            durationMs - bounded <=
                PlaybackProgress.completionTail.inMilliseconds);
    await _write([
      _content(item),
      SqlStatement(
        '''INSERT INTO playback_progress(source,content_id,part_id,position_ms,duration_ms,completed,updated_at)
        VALUES(?,?,?,?,?,?,?)
        ON CONFLICT(source,content_id,part_id) DO UPDATE SET
          position_ms=excluded.position_ms,
          duration_ms=CASE WHEN excluded.duration_ms>0 THEN excluded.duration_ms ELSE playback_progress.duration_ms END,
          completed=excluded.completed,
          updated_at=excluded.updated_at
        WHERE excluded.updated_at >= playback_progress.updated_at''',
        [
          ..._identity(item.identity),
          LibraryCodec.id(partId),
          bounded,
          durationMs,
          finished ? 1 : 0,
          _now,
        ],
      ),
    ]);
  }

  @override
  Future<void> removeProgress(PlaybackPart part) => _write([
    SqlStatement(
      'DELETE FROM playback_progress WHERE source=? AND content_id=? AND part_id=?',
      _part(part),
    ),
    _prune,
  ]);

  @override
  Future<void> clearProgress() =>
      _write([const SqlStatement('DELETE FROM playback_progress'), _prune]);

  @override
  Future<List<PlaybackBookmark>> bookmarks(PlaybackPart part) async {
    final rows = (await _batch([
      SqlStatement(
        'SELECT id,source,content_id,part_id,start_ms,end_ms,title,note,created_at,updated_at '
        'FROM playback_bookmarks WHERE source=? AND content_id=? AND part_id=? '
        'ORDER BY start_ms,id',
        _part(part),
        true,
      ),
    ])).single;
    return [for (final row in rows) _bookmark(row)];
  }

  @override
  Future<String> addBookmark(
    ContentSnapshot item,
    String partId,
    Duration start, {
    Duration? end,
    String title = '',
    String note = '',
  }) async {
    final startMs = _millis(start);
    final endMs = end == null ? null : _millis(end);
    if (endMs != null && endMs < startMs) {
      throw const StorageFailure(StorageFailureKind.invalidData);
    }
    final id = _localId();
    await _write([
      _content(item),
      SqlStatement(
        '''INSERT INTO playback_bookmarks(id,source,content_id,part_id,start_ms,end_ms,title,note,created_at,updated_at)
        VALUES(?,?,?,?,?,?,?,?,?,?)''',
        [
          id,
          ..._identity(item.identity),
          LibraryCodec.id(partId),
          startMs,
          endMs,
          _bookmarkText(title.trim(), 200),
          _bookmarkText(note, 2000),
          _now,
          _now,
        ],
      ),
    ]);
    return id;
  }

  @override
  Future<void> updateBookmark(
    String id, {
    String? title,
    String? note,
    Duration? start,
    Duration? end,
    bool clearEnd = false,
  }) async {
    if (clearEnd && end != null) {
      throw const StorageFailure(StorageFailureKind.invalidData);
    }
    final assignments = <String>[];
    final parameters = <Object?>[];
    if (title != null) {
      assignments.add('title=?');
      parameters.add(_bookmarkText(title.trim(), 200));
    }
    if (note != null) {
      assignments.add('note=?');
      parameters.add(_bookmarkText(note, 2000));
    }
    if (start != null) {
      assignments.add('start_ms=?');
      parameters.add(_millis(start));
    }
    if (clearEnd) {
      assignments.add('end_ms=NULL');
    } else if (end != null) {
      assignments.add('end_ms=?');
      parameters.add(_millis(end));
    }
    if (assignments.isEmpty) return;
    assignments.add('updated_at=?');
    parameters.add(_now);
    // The table's own CHECK rejects an end before the start, so a partial update
    // cannot leave an inverted range behind.
    await _write([
      SqlStatement(
        'UPDATE playback_bookmarks SET ${assignments.join(',')} WHERE id=?',
        [...parameters, id],
      ),
    ]);
  }

  @override
  Future<void> removeBookmark(String id) => _write([
    SqlStatement('DELETE FROM playback_bookmarks WHERE id=?', [id]),
    _prune,
  ]);

  @override
  Future<List<LocalSubscription>> subscriptions() async {
    final rows = (await _batch([
      const SqlStatement(
        'SELECT mid,name,avatar FROM local_subscriptions ORDER BY added_at DESC,mid',
        [],
        true,
      ),
    ])).single;
    return [
      for (final row in rows)
        LocalSubscription(
          mid: row['mid'] as String,
          name: row['name'] as String,
          avatar: LibraryCodec.publicUri(row['avatar']),
        ),
    ];
  }

  @override
  Future<void> subscribe(LocalSubscription creator) {
    if (!LocalSubscription.validMid(creator.mid) ||
        creator.name.length > 1000) {
      throw const StorageFailure(StorageFailureKind.invalidData);
    }
    return _write([
      SqlStatement(
        '''INSERT INTO local_subscriptions VALUES(?,?,?,?) ON CONFLICT(mid) DO UPDATE SET name=excluded.name,avatar=COALESCE(excluded.avatar,local_subscriptions.avatar)''',
        [
          creator.mid,
          creator.name.trim(),
          LibraryCodec.publicUri(creator.avatar)?.toString(),
          _now,
        ],
      ),
    ], subscriptions: true);
  }

  @override
  Future<void> unsubscribe(String mid) => _write([
    SqlStatement('DELETE FROM local_subscriptions WHERE mid=?', [mid]),
  ], subscriptions: true);
  @override
  Future<List<CalendarFollow>> calendarFollows() async {
    final rows = (await _batch([
      const SqlStatement(
        'SELECT * FROM calendar_follows ORDER BY followed_at DESC,source,uid,recurrence_id',
        [],
        true,
      ),
    ])).single;
    return [for (final row in rows) _follow(row)];
  }

  static CalendarFollow _follow(SqlRow row) {
    final event = LibraryCodec.decodeEvent(row['snapshot'] as String);
    if (event.uid != row['uid'] ||
        (event.recurrenceId ?? '') != row['recurrence_id']) {
      throw const StorageFailure(StorageFailureKind.invalidData);
    }
    final observed = row['observed_at'] as int;
    return CalendarFollow(
      key: CalendarFollowKey(
        source: Uri.parse(row['source'] as String),
        uid: event.uid,
        recurrenceId: event.recurrenceId,
      ),
      event: event,
      followedAt: DateTime.fromMillisecondsSinceEpoch(
        row['followed_at'] as int,
        isUtc: true,
      ),
      observedAt: observed == 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(observed, isUtc: true),
    );
  }

  @override
  Future<void> followCalendar(CalendarFollowKey key, CalendarEvent event) {
    if (key.uid != event.uid ||
        key.recurrenceId != event.recurrenceId ||
        LibraryCodec.publicUri(key.source) == null) {
      throw const StorageFailure(StorageFailureKind.invalidData);
    }
    final encoded = LibraryCodec.encodeEvent(event);
    return _write([
      SqlStatement(
        'INSERT INTO calendar_follows VALUES(?,?,?,?,?,?,0) ON CONFLICT DO NOTHING',
        [..._key(key), encoded, event.sequence, _now],
      ),
    ]);
  }

  @override
  Future<void> unfollowCalendar(CalendarFollowKey key) => _write([
    SqlStatement(
      'DELETE FROM calendar_follows WHERE source=? AND uid=? AND recurrence_id=?',
      _key(key),
    ),
  ]);
  @override
  Future<void> synchronizeCalendar(
    Uri source,
    List<CalendarEvent> events,
    DateTime observedAt,
  ) async {
    final followed = (await _batch([
      SqlStatement(
        'SELECT uid,recurrence_id,sequence,observed_at FROM calendar_follows WHERE source=?',
        [source.toString()],
        true,
      ),
    ])).single;
    if (followed.isEmpty) return;
    final byKey = {
      for (final event in events)
        CalendarFollowKey(
          source: source,
          uid: event.uid,
          recurrenceId: event.recurrenceId,
        ): event,
    };
    final commands = <SqlStatement>[];
    final observed = observedAt.millisecondsSinceEpoch;
    for (final old in followed) {
      final key = CalendarFollowKey(
        source: source,
        uid: old['uid'] as String,
        recurrenceId: old['recurrence_id'] == ''
            ? null
            : old['recurrence_id'] as String,
      );
      final event = byKey[key];
      // Absence is not cancellation. SQL repeats revision guards so a second
      // process cannot race this bounded metadata read with a newer snapshot.
      if (event == null ||
          event.sequence < (old['sequence'] as int) ||
          observed < (old['observed_at'] as int) ||
          (observed == old['observed_at'] &&
              event.sequence == old['sequence'])) {
        continue;
      }
      commands.add(
        SqlStatement(
          'UPDATE calendar_follows SET snapshot=?,sequence=?,observed_at=? WHERE source=? AND uid=? AND recurrence_id=? AND sequence<=? AND observed_at<=?',
          [
            LibraryCodec.encodeEvent(event),
            event.sequence,
            observed,
            ..._key(key),
            event.sequence,
            observed,
          ],
        ),
      );
    }
    if (commands.isNotEmpty) await _write(commands);
  }
}

// Only send detached rows and static decoders, never the repository/Future
// queue/ProviderRef. Tests with an in-memory store can opt out of isolates.
Future<List<T>> _decodeRows<T>(List<SqlRow> rows, T Function(SqlRow) decode) =>
    Isolate.run(() => rows.map(decode).toList());
