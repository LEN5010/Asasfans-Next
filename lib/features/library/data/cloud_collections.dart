import '../../../core/domain/content_identity.dart';
import '../../../core/storage/local_database.dart';
import '../domain/library_models.dart';
import 'library_codec.dart';

String? cloudKey(ContentIdentity identity) => switch (identity.source) {
  ContentSource.bilibiliDynamic => 'bili:${identity.value}',
  ContentSource.doubanTopic => 'douban:${identity.value}',
  ContentSource.bilibiliVideo => null,
};

ContentIdentity? cloudIdentity(String key) {
  final match = RegExp(r'^(bili|douban):([1-9][0-9]{0,31})$').firstMatch(key);
  return match == null
      ? null
      : ContentIdentity(
          source: match[1] == 'bili'
              ? ContentSource.bilibiliDynamic
              : ContentSource.doubanTopic,
          value: match[2]!,
        );
}

String cloudKeySql(String alias) =>
    "CASE $alias.source WHEN 'bilibiliDynamic' THEN 'bili:'||$alias.content_id "
    "WHEN 'doubanTopic' THEN 'douban:'||$alias.content_id END";

class CloudFavorite {
  const CloudFavorite(this.key, this.addedAt, this.snapshot);
  final String key;
  final int addedAt;
  final ContentSnapshot? snapshot;
}

/// Uses the same database transactions as collection edits and backup imports.
class CloudCollections {
  CloudCollections(this.db, this.owner);
  final LocalDatabase db;
  final String owner;
  String get _initialized => 'account.collections.initialized.$owner';

  Future<bool> initialized() async => (await db.batch([
    SqlStatement('SELECT 1 FROM preferences WHERE key=?', [_initialized], true),
  ])).single.isNotEmpty;

  Future<void> initialize({required bool importLocal}) async {
    final commands = <SqlStatement>[
      SqlStatement(
        "INSERT INTO collection_folders(owner,id,name,created_at) VALUES(?,'default','默认收藏夹',0) ON CONFLICT DO NOTHING",
        [owner],
      ),
      if (importLocal) ...[
        SqlStatement(
          "INSERT INTO collection_folders SELECT ?,id,name,created_at FROM collection_folders WHERE owner='local' ON CONFLICT DO NOTHING",
          [owner],
        ),
        SqlStatement(
          "INSERT INTO collection_items SELECT ?,folder_id,source,content_id,added_at FROM collection_items WHERE owner='local' ON CONFLICT DO NOTHING",
          [owner],
        ),
        queueCurrent(owner),
      ],
      SqlStatement(
        "INSERT INTO preferences VALUES(?,'true') ON CONFLICT DO NOTHING",
        [_initialized],
      ),
    ];
    await db.batch(commands, write: true);
  }

  static SqlStatement queueCurrent(String owner) => SqlStatement(
    'INSERT INTO cloud_outbox(owner,key,op,queued_at) '
    "SELECT DISTINCT owner,${cloudKeySql('i')},'add',? FROM collection_items i "
    "WHERE owner=? AND owner<>'local' AND source IN ('bilibiliDynamic','doubanTopic') "
    'ON CONFLICT(owner,key) DO UPDATE SET op=excluded.op,queued_at=MAX(cloud_outbox.queued_at+1,excluded.queued_at)',
    [DateTime.now().microsecondsSinceEpoch, owner],
  );

  Future<List<SqlRow>> pending({bool all = false}) async => (await db.batch([
    SqlStatement(
      'SELECT key,op,queued_at FROM cloud_outbox WHERE owner=? ORDER BY queued_at,key ${all ? '' : 'LIMIT 200'}',
      [owner],
      true,
    ),
  ])).single;

  Future<void> acknowledge(List<SqlRow> submitted, Set<String> unknown) async {
    await db.batch([
      for (final row in submitted)
        if (!unknown.contains(row['key']))
          SqlStatement(
            'DELETE FROM cloud_outbox WHERE owner=? AND key=? AND queued_at=?',
            [owner, row['key'], row['queued_at']],
          ),
    ], write: true);
  }

  /// All remote pages are read before this one reconciliation transaction.
  Future<void> reconcile(List<CloudFavorite> remote) async {
    final commands = <SqlStatement>[
      const SqlStatement(
        'CREATE TEMP TABLE sync_keys(key TEXT PRIMARY KEY) WITHOUT ROWID',
      ),
    ];
    final unique = <String, CloudFavorite>{};
    for (final item in remote) {
      if (cloudIdentity(item.key) != null) {
        final previous = unique[item.key];
        if (previous == null || previous.snapshot == null) {
          unique[item.key] = item;
        }
      }
    }
    for (final item in unique.values) {
      final identity = cloudIdentity(item.key)!;
      commands.add(SqlStatement('INSERT INTO sync_keys VALUES(?)', [item.key]));
      if (item.snapshot != null) {
        commands.add(
          SqlStatement(
            'INSERT INTO content_refs(source,content_id,snapshot,updated_at) VALUES(?,?,?,?) '
            'ON CONFLICT(source,content_id) DO NOTHING',
            [
              identity.source.name,
              identity.value,
              LibraryCodec.encodeContent(item.snapshot!),
              item.addedAt,
            ],
          ),
        );
      }
      commands.add(
        SqlStatement(
          "INSERT INTO collection_items(owner,folder_id,source,content_id,added_at) "
          "SELECT ?,'default',source,content_id,? FROM content_refs c WHERE source=? AND content_id=? "
          'AND NOT EXISTS(SELECT 1 FROM collection_items i WHERE i.owner=? AND i.source=c.source AND i.content_id=c.content_id) '
          "AND NOT EXISTS(SELECT 1 FROM cloud_outbox WHERE owner=? AND key=? AND op='remove') "
          'ON CONFLICT DO NOTHING',
          [
            owner,
            item.addedAt,
            identity.source.name,
            identity.value,
            owner,
            owner,
            item.key,
          ],
        ),
      );
    }
    commands.addAll([
      SqlStatement(
        "DELETE FROM collection_items AS i WHERE owner=? AND source IN ('bilibiliDynamic','doubanTopic') "
        "AND NOT EXISTS(SELECT 1 FROM sync_keys WHERE key=${cloudKeySql('i')}) "
        "AND NOT EXISTS(SELECT 1 FROM cloud_outbox WHERE owner=i.owner AND key=${cloudKeySql('i')})",
        [owner],
      ),
      const SqlStatement('DROP TABLE sync_keys'),
      const SqlStatement(
        'DELETE FROM content_refs AS c '
        'WHERE NOT EXISTS(SELECT 1 FROM collection_items i WHERE i.source=c.source AND i.content_id=c.content_id) '
        'AND NOT EXISTS(SELECT 1 FROM watch_later i WHERE i.source=c.source AND i.content_id=c.content_id) '
        'AND NOT EXISTS(SELECT 1 FROM content_history i WHERE i.source=c.source AND i.content_id=c.content_id) '
        'AND NOT EXISTS(SELECT 1 FROM playback_progress i WHERE i.source=c.source AND i.content_id=c.content_id) '
        'AND NOT EXISTS(SELECT 1 FROM playback_bookmarks i WHERE i.source=c.source AND i.content_id=c.content_id)',
      ),
    ]);
    await db.batch(commands, write: true);
  }
}
