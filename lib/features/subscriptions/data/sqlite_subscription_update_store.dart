import 'dart:async';

import '../../../core/domain/bilibili_id.dart';
import '../../../core/storage/local_database.dart';
import '../../../core/storage/storage_failure.dart';
import '../../library/data/library_codec.dart';
import '../../library/domain/library_models.dart';
import '../domain/subscription_updates.dart';

class SqliteSubscriptionUpdateStore implements SubscriptionUpdateStore {
  SqliteSubscriptionUpdateStore(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final LocalDatabase _db;
  final DateTime Function() _clock;
  final _changes = StreamController<int>.broadcast();
  var _revision = 0;
  bool _closed = false;
  @override
  Stream<int> get changes => _changes.stream;
  void _check() {
    if (_closed) throw const StorageFailure(StorageFailureKind.closed);
  }

  static const _stamp = SqlStatement(
    'SELECT l.store_id,s.revision FROM library_meta l CROSS JOIN subscription_meta s WHERE l.singleton=1 AND s.singleton=1',
    [],
    true,
  );
  @override
  Future<SubscriptionRoster> roster() async {
    _check();
    final rows = await _db.batch([
      _stamp,
      const SqlStatement(
        'SELECT mid,name,avatar FROM local_subscriptions ORDER BY mid',
        [],
        true,
      ),
    ]);
    final stamp = rows.first.single;
    final creators = <LocalSubscription>[];
    for (final row in rows.last) {
      final mid = row['mid'];
      final name = row['name'];
      if (mid is! String ||
          !validBilibiliMid(mid) ||
          name is! String ||
          name.length > 1000) {
        throw const StorageFailure(StorageFailureKind.invalidData);
      }
      creators.add(
        LocalSubscription(
          mid: mid,
          name: name,
          avatar: LibraryCodec.publicUri(row['avatar']),
        ),
      );
    }
    _check();
    return SubscriptionRoster(
      storeId: stamp['store_id'] as String,
      revision: stamp['revision'] as int,
      creators: creators,
    );
  }

  @override
  Future<void> checkRoster(SubscriptionRoster roster) async {
    _check();
    final stamp = (await _db.batch([_stamp])).single.single;
    _check();
    if (stamp['store_id'] != roster.storeId ||
        stamp['revision'] != roster.revision) {
      throw const StorageFailure(StorageFailureKind.changed);
    }
  }

  List<String> _ids(Iterable<String> ids) {
    final values = ids.toSet().toList();
    if (values.any((id) => !validBvid(id))) {
      throw const StorageFailure(StorageFailureKind.invalidData);
    }
    return values;
  }

  @override
  Future<Map<String, bool>> readStates(Iterable<String> bvids) async {
    _check();
    final ids = _ids(bvids);
    final batches = <SqlStatement>[];
    for (var start = 0; start < ids.length; start += 400) {
      final part = ids.skip(start).take(400).toList();
      batches.add(
        SqlStatement(
          'SELECT bvid,is_read FROM subscription_reads WHERE bvid IN (${part.map((_) => '?').join(',')})',
          part,
          true,
        ),
      );
    }
    if (batches.isEmpty) return {};
    final rows = await _db.batch(batches);
    _check();
    return {
      for (final group in rows)
        for (final row in group) row['bvid'] as String: row['is_read'] == 1,
    };
  }

  @override
  Future<void> mark(Iterable<String> bvids, {required bool read}) async {
    _check();
    final ids = _ids(bvids);
    if (ids.isEmpty) return;
    final at = _clock().toUtc().millisecondsSinceEpoch;
    if (at < 0 || at > 253402300799999) {
      throw const StorageFailure(StorageFailureKind.invalidData);
    }
    await _db.batch([
      for (final id in ids)
        SqlStatement(
          '''INSERT INTO subscription_reads(bvid,is_read,updated_at) VALUES(?,?,?)
      ON CONFLICT(bvid) DO UPDATE SET is_read=excluded.is_read,updated_at=excluded.updated_at''',
          [id, read ? 1 : 0, at],
        ),
    ], write: true);
    if (!_closed) _changes.add(++_revision);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _changes.close();
  }
}
