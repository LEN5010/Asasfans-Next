import 'dart:isolate';
import 'dart:typed_data';

import '../../../core/storage/local_database.dart';
import '../domain/personal_backup.dart';
import 'backup_codec.dart';

class SqliteBackupRepository implements BackupRepository {
  SqliteBackupRepository(
    this._db, {
    required this.onCommitted,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;
  final LocalDatabase _db;
  final void Function() onCommitted;
  final DateTime Function() _clock;

  // Every SELECT observes the same transaction. The budget predicates prevent
  // a giant store from first being materialized in memory just to reject it.
  static final _budget =
      '''WITH budget AS (SELECT
    (${BackupCodec.columns.entries.map((entry) => '(SELECT COALESCE(SUM(${entry.value.map((column) => 'COALESCE(length(CAST($column AS BLOB)),0)').join('+')}+512),0) FROM ${entry.key})').join('+')}) AS bytes,
    (${BackupCodec.columns.keys.map((table) => '(SELECT COUNT(*) FROM $table)').join('+')}) AS rows)
  ''';
  static final _preferences =
      "key IN (${BackupCodec.preferenceKeys.map((_) => '?').join(',')})";

  @override
  Future<Uint8List> export() async {
    final at = _clock().toUtc();
    final result = await _db.batch([
      SqlStatement('$_budget SELECT bytes,rows FROM budget', [], true),
      for (final entry in BackupCodec.columns.entries)
        SqlStatement(
          '$_budget SELECT ${entry.value.join(',')} FROM ${entry.key} '
          'WHERE EXISTS(SELECT 1 FROM budget WHERE bytes<=? AND rows<=?) '
          '${entry.key == 'preferences' ? 'AND $_preferences' : ''}',
          [
            BackupCodec.maxBytes ~/ 2,
            BackupCodec.maxRows,
            if (entry.key == 'preferences') ...BackupCodec.preferenceKeys,
          ],
          true,
        ),
    ]);
    final budget = result.first.single;
    if ((budget['bytes'] as int) > BackupCodec.maxBytes ~/ 2 ||
        (budget['rows'] as int) > BackupCodec.maxRows) {
      throw const BackupFailure(BackupFailureKind.tooLarge);
    }
    final tables = {
      for (final entry in BackupCodec.columns.keys.indexed)
        entry.$2: result[entry.$1 + 1],
    };
    return _encode(tables, at);
  }

  @override
  Future<BackupImport> inspect(Uint8List bytes) {
    if (bytes.length > BackupCodec.maxBytes) {
      return Future.error(const BackupFailure(BackupFailureKind.tooLarge));
    }
    return _inspect(Uint8List.fromList(bytes));
  }

  @override
  Future<void> merge(BackupImport backup) async {
    if (backup is! ValidatedBackup) {
      throw const BackupFailure(BackupFailureKind.invalid);
    }
    final commands = <SqlStatement>[];
    // The fixed table order places content and folders before their relations.
    // No SQL identifiers or clauses are read from the file.
    for (final entry in BackupCodec.columns.entries) {
      final conflict = switch (entry.key) {
        'content_refs' =>
          '''ON CONFLICT(source,content_id) DO UPDATE SET snapshot=excluded.snapshot,updated_at=excluded.updated_at
          WHERE excluded.updated_at>content_refs.updated_at''',
        'content_history' =>
          '''ON CONFLICT(source,content_id,action) DO UPDATE SET
          last_at=MAX(content_history.last_at,excluded.last_at),visits=MAX(content_history.visits,excluded.visits)''',
        'calendar_follows' =>
          '''ON CONFLICT(source,uid,recurrence_id) DO UPDATE SET
          snapshot=excluded.snapshot,sequence=excluded.sequence,observed_at=excluded.observed_at
          WHERE excluded.sequence>=calendar_follows.sequence AND excluded.observed_at>=calendar_follows.observed_at
          AND (excluded.sequence>calendar_follows.sequence OR excluded.observed_at>calendar_follows.observed_at)''',
        _ => 'ON CONFLICT DO NOTHING',
      };
      for (final row in backup.tables[entry.key]!) {
        commands.add(
          SqlStatement(
            'INSERT INTO ${entry.key}(${entry.value.join(',')}) VALUES(${entry.value.map((_) => '?').join(',')}) $conflict',
            entry.value.map((key) => row[key]).toList(),
          ),
        );
      }
    }
    await _db.batch(commands, write: true);
    // Only a committed transaction wakes consumers; a failed import is atomic.
    onCommitted();
  }
}

Future<Uint8List> _encode(Map<String, List<SqlRow>> rows, DateTime at) =>
    Isolate.run(() => BackupCodec.encode(rows, at));
Future<ValidatedBackup> _inspect(Uint8List bytes) =>
    Isolate.run(() => BackupCodec.decode(bytes));
