import 'dart:convert';
import 'dart:math';

import '../../../core/domain/content_identity.dart';
import '../../../core/storage/local_database.dart';
import '../domain/return_context.dart';

/// Persists the one live return session.
///
/// Writing it to disk rather than holding it in memory is the whole point: the
/// process may be reclaimed while Bilibili is in the foreground, and a cold
/// start still has to know which list the user was picking from.
abstract interface class ReturnStore {
  /// Replaces any previous session. Starting a new handoff abandons the old
  /// one rather than queueing behind it.
  Future<void> save(ReturnContext context);

  /// The stored session, or null when there is none.
  Future<ReturnContext?> read();

  /// Marks the session used and returns it, or null when there was nothing to
  /// consume or it was already consumed.
  ///
  /// This is the single-consumption guarantee: one system callback restores
  /// once, and a repeat cannot drive a second restore.
  Future<ReturnContext?> consume(String sessionId);

  /// Drops the session entirely, for an explicit end rather than a return.
  Future<void> clear();
}

class SqliteReturnStore implements ReturnStore {
  SqliteReturnStore(this._db);
  final LocalDatabase _db;

  static String newSessionId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  @override
  Future<void> save(ReturnContext context) async {
    await _db.batch([
      SqlStatement(
        '''INSERT INTO return_sessions(
          singleton,session_id,target,channel,query,anchor,
          opened_source,opened_id,created_at,consumed)
        VALUES(1,?,?,?,?,?,?,?,?,?)
        ON CONFLICT(singleton) DO UPDATE SET
          session_id=excluded.session_id,
          target=excluded.target,
          channel=excluded.channel,
          query=excluded.query,
          anchor=excluded.anchor,
          opened_source=excluded.opened_source,
          opened_id=excluded.opened_id,
          created_at=excluded.created_at,
          consumed=excluded.consumed''',
        [
          context.sessionId,
          context.target.name,
          context.channel,
          context.encodeQuery(),
          context.encodeAnchor(),
          context.openedContent?.source.name,
          context.openedContent?.value,
          context.createdAt.toUtc().millisecondsSinceEpoch,
          context.consumed ? 1 : 0,
        ],
      ),
    ], write: true);
  }

  @override
  Future<ReturnContext?> read() async {
    final rows = (await _db.batch([
      SqlStatement(
        'SELECT session_id,target,channel,query,anchor,opened_source,'
        'opened_id,created_at,consumed FROM return_sessions WHERE singleton=1',
        [],
        true,
      ),
    ])).single;
    return rows.isEmpty ? null : _decode(rows.single);
  }

  @override
  Future<ReturnContext?> consume(String sessionId) async {
    // Match the id inside the same statement that flips the flag, so two
    // callbacks racing cannot both observe an unconsumed session.
    final results = await _db.batch([
      SqlStatement(
        'UPDATE return_sessions SET consumed=1 '
        'WHERE singleton=1 AND session_id=? AND consumed=0',
        [sessionId],
      ),
      SqlStatement('SELECT changes() AS updated', [], true),
      SqlStatement(
        'SELECT session_id,target,channel,query,anchor,opened_source,'
        'opened_id,created_at,consumed FROM return_sessions WHERE singleton=1',
        [],
        true,
      ),
    ], write: true);
    if ((results[1].single['updated'] as int) == 0) return null;
    final rows = results[2];
    return rows.isEmpty ? null : _decode(rows.single);
  }

  @override
  Future<void> clear() async {
    await _db.batch([
      SqlStatement('DELETE FROM return_sessions WHERE singleton=1'),
    ], write: true);
  }

  static ReturnContext? _decode(SqlRow row) {
    final target = ReturnTarget.values
        .where((value) => value.name == row['target'])
        .firstOrNull;
    if (target == null) return null;
    final source = ContentSource.values
        .where((value) => value.name == row['opened_source'])
        .firstOrNull;
    final openedId = row['opened_id'];
    return ReturnContext(
      sessionId: row['session_id'] as String,
      target: target,
      channel: row['channel'] as String?,
      query: _map(row['query']),
      anchor: ReturnAnchor.fromJson(_map(row['anchor'])),
      openedContent: source == null || openedId is! String
          ? null
          : ContentIdentity(source: source, value: openedId),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row['created_at'] as int,
        isUtc: true,
      ),
      consumed: row['consumed'] == 1,
    );
  }

  /// A stored blob that no longer parses costs the position, not the return:
  /// the target and channel are separate columns and still stand on their own.
  static Map<String, Object?>? _map(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, Object?> && decoded.isNotEmpty
          ? decoded
          : null;
    } on FormatException {
      return null;
    }
  }
}
