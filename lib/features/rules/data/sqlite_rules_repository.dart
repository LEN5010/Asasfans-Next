import 'dart:async';

import '../../../core/storage/local_database.dart';
import '../../../core/storage/storage_failure.dart';
import '../domain/content_rules.dart';
import '../domain/rules_repository.dart';
import 'rules_codec.dart';

class SqliteRulesRepository implements RulesRepository {
  SqliteRulesRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final LocalDatabase _db;
  final DateTime Function() _clock;
  final _changes = StreamController<int>.broadcast();
  var _revision = 0;
  bool _closed = false;
  int get _now => _clock().toUtc().millisecondsSinceEpoch;
  @override
  Stream<int> get changes => _changes.stream;
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

  static List<Object?> _values(RuleDraft draft) => [
    draft.kind.name,
    draft.scope,
    draft.value,
    draft.enabled ? 1 : 0,
    draft.expiresAt?.millisecondsSinceEpoch,
  ];
  static const _changed = SqlStatement('SELECT changes() AS n', [], true);

  @override
  Future<RulesSnapshot> load() async {
    final results = await _batch([
      const SqlStatement(
        'SELECT * FROM content_rules ORDER BY created_at DESC,id LIMIT 1001',
        [],
        true,
      ),
      const SqlStatement('SELECT mid FROM local_subscriptions', [], true),
      const SqlStatement(
        "SELECT value FROM rule_settings WHERE key='subscribed_first'",
        [],
        true,
      ),
    ]);
    if (results[0].length > RulesCodec.maxRules) {
      throw const RuleFailure(RuleFailureKind.limitReached);
    }
    final value = results[2].firstOrNull?['value'];
    if (value != null && value != 'true' && value != 'false') {
      throw const StorageFailure(StorageFailureKind.invalidData);
    }
    return RulesSnapshot(
      rules: results[0].map(RulesCodec.decode).toList(),
      subscriptions: results[1].map((r) => r['mid'] as String).toSet(),
      prioritizeSubscribed: value == 'true',
    );
  }

  @override
  Future<RuleChange> save(RuleDraft input, {ContentRule? previous}) async {
    final draft = input.normalized();
    final now = _now;
    RulesCodec.time(now);
    late final SqlResults result;
    if (previous == null) {
      final identity = [draft.kind.name, draft.scope, draft.value];
      result = await _batch([
        SqlStatement(
          'SELECT * FROM content_rules WHERE kind=? AND scope=? AND value=?',
          identity,
          true,
        ),
        SqlStatement(
          '''INSERT INTO content_rules(id,kind,scope,value,enabled,expires_at,created_at,updated_at)
          SELECT lower(hex(randomblob(16))),?,?,?,?,?,?,?
          WHERE (SELECT COUNT(*) FROM content_rules)<1000 OR EXISTS(SELECT 1 FROM content_rules WHERE kind=? AND scope=? AND value=?)
          ON CONFLICT(kind,scope,value) DO UPDATE SET enabled=excluded.enabled,expires_at=excluded.expires_at,
          updated_at=MAX(content_rules.updated_at,excluded.updated_at),change_token=lower(hex(randomblob(16)))''',
          [..._values(draft), now, now, ...identity],
        ),
        _changed,
        SqlStatement(
          'SELECT * FROM content_rules WHERE kind=? AND scope=? AND value=?',
          identity,
          true,
        ),
      ], write: true);
      if (result[2].single['n'] != 1) {
        throw const RuleFailure(RuleFailureKind.limitReached);
      }
    } else {
      result = await _batch([
        SqlStatement(
          'SELECT * FROM content_rules WHERE id=? AND change_token=?',
          [previous.id, previous.changeToken],
          true,
        ),
        SqlStatement(
          '''UPDATE content_rules SET kind=?,scope=?,value=?,enabled=?,expires_at=?,
          updated_at=MAX(updated_at,?),change_token=lower(hex(randomblob(16)))
          WHERE id=? AND change_token=? AND NOT EXISTS(SELECT 1 FROM content_rules WHERE kind=? AND scope=? AND value=? AND id<>?)''',
          [
            ..._values(draft),
            now,
            previous.id,
            previous.changeToken,
            draft.kind.name,
            draft.scope,
            draft.value,
            previous.id,
          ],
        ),
        _changed,
        SqlStatement('SELECT * FROM content_rules WHERE id=?', [
          previous.id,
        ], true),
      ], write: true);
      if (result[2].single['n'] != 1) {
        throw const RuleFailure(RuleFailureKind.changed);
      }
    }
    final change = RuleChange(
      before: result[0].isEmpty ? null : RulesCodec.decode(result[0].single),
      after: RulesCodec.decode(result[3].single),
    );
    _notify();
    return change;
  }

  @override
  Future<RuleChange> remove(ContentRule rule) async {
    final results = await _batch([
      SqlStatement(
        'SELECT * FROM content_rules WHERE id=? AND change_token=?',
        [rule.id, rule.changeToken],
        true,
      ),
      SqlStatement('DELETE FROM content_rules WHERE id=? AND change_token=?', [
        rule.id,
        rule.changeToken,
      ]),
      _changed,
    ], write: true);
    if (results.last.single['n'] != 1) {
      throw const RuleFailure(RuleFailureKind.changed);
    }
    final change = RuleChange(before: RulesCodec.decode(results.first.single));
    _notify();
    return change;
  }

  @override
  Future<bool> undo(RuleChange change) async {
    final before = change.before;
    final after = change.after;
    late final SqlStatement statement;
    if (before == null && after != null) {
      statement = SqlStatement(
        'DELETE FROM content_rules WHERE id=? AND change_token=?',
        [after.id, after.changeToken],
      );
    } else if (before != null && after == null) {
      statement = SqlStatement(
        '''INSERT INTO content_rules(id,kind,scope,value,enabled,expires_at,created_at,updated_at)
        SELECT ?,?,?,?,?,?,?,? WHERE (SELECT COUNT(*) FROM content_rules)<1000
        AND NOT EXISTS(SELECT 1 FROM content_rules WHERE id=? OR (kind=? AND scope=? AND value=?))''',
        [
          before.id,
          ..._values(before.draft),
          before.createdAt.millisecondsSinceEpoch,
          before.updatedAt.millisecondsSinceEpoch,
          before.id,
          before.draft.kind.name,
          before.draft.scope,
          before.draft.value,
        ],
      );
    } else if (before != null && after != null) {
      statement = SqlStatement(
        '''UPDATE content_rules SET kind=?,scope=?,value=?,enabled=?,expires_at=?,
        updated_at=MAX(updated_at,?),change_token=lower(hex(randomblob(16))) WHERE id=? AND change_token=?
        AND NOT EXISTS(SELECT 1 FROM content_rules WHERE kind=? AND scope=? AND value=? AND id<>?)''',
        [
          ..._values(before.draft),
          _now,
          after.id,
          after.changeToken,
          before.draft.kind.name,
          before.draft.scope,
          before.draft.value,
          after.id,
        ],
      );
    } else {
      return false;
    }
    final result = await _batch([statement, _changed], write: true);
    final changed = result.last.single['n'] == 1;
    if (changed) _notify();
    return changed;
  }

  @override
  Future<void> setSubscriptionPriority(bool enabled) async {
    await _batch([
      SqlStatement(
        "INSERT INTO rule_settings VALUES('subscribed_first',?) ON CONFLICT(key) DO UPDATE SET value=excluded.value WHERE rule_settings.value<>excluded.value",
        ['$enabled'],
      ),
    ], write: true);
    _notify();
  }

  @override
  Future<void> close() async {
    if (!_closed) {
      _closed = true;
      await _changes.close();
    }
  }
}
