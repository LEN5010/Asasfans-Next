/// Version 2 adds only entities used by the personal-library feature.
const librarySchemaV2 = <String>[
  '''CREATE TABLE content_refs (
    source TEXT NOT NULL, content_id TEXT NOT NULL, snapshot TEXT NOT NULL,
    updated_at INTEGER NOT NULL, PRIMARY KEY(source, content_id)
  ) WITHOUT ROWID''',
  '''CREATE TABLE collection_folders (
    id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL, created_at INTEGER NOT NULL
  ) WITHOUT ROWID''',
  "INSERT INTO collection_folders VALUES ('default', '默认收藏夹', 0)",
  '''CREATE TABLE collection_items (
    folder_id TEXT NOT NULL REFERENCES collection_folders(id) ON DELETE CASCADE,
    source TEXT NOT NULL, content_id TEXT NOT NULL, added_at INTEGER NOT NULL,
    PRIMARY KEY(folder_id, source, content_id),
    FOREIGN KEY(source, content_id) REFERENCES content_refs(source, content_id)
  ) WITHOUT ROWID''',
  '''CREATE TABLE watch_later (
    source TEXT NOT NULL, content_id TEXT NOT NULL, added_at INTEGER NOT NULL,
    done INTEGER NOT NULL DEFAULT 0 CHECK(done IN (0,1)),
    PRIMARY KEY(source, content_id),
    FOREIGN KEY(source, content_id) REFERENCES content_refs(source, content_id)
  ) WITHOUT ROWID''',
  '''CREATE TABLE content_history (
    source TEXT NOT NULL, content_id TEXT NOT NULL,
    action TEXT NOT NULL CHECK(action IN ('detail','external','playback')),
    last_at INTEGER NOT NULL, visits INTEGER NOT NULL DEFAULT 1 CHECK(visits > 0),
    PRIMARY KEY(source, content_id, action),
    FOREIGN KEY(source, content_id) REFERENCES content_refs(source, content_id)
  ) WITHOUT ROWID''',
  'CREATE INDEX history_recent ON content_history(last_at DESC, source, content_id, action)',
  '''CREATE TABLE local_subscriptions (
    mid TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL, avatar TEXT,
    added_at INTEGER NOT NULL
  ) WITHOUT ROWID''',
  '''CREATE TABLE calendar_follows (
    source TEXT NOT NULL, uid TEXT NOT NULL, recurrence_id TEXT NOT NULL,
    snapshot TEXT NOT NULL, sequence INTEGER NOT NULL,
    followed_at INTEGER NOT NULL, observed_at INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY(source, uid, recurrence_id)
  ) WITHOUT ROWID''',
];

/// Cursor revisions also observe writes made by other app instances. Cache and
/// preference writes deliberately do not invalidate personal-library cursors.
final librarySchemaV3 = <String>[
  '''CREATE TABLE library_meta (
    singleton INTEGER NOT NULL PRIMARY KEY CHECK(singleton=1),
    store_id TEXT NOT NULL, revision INTEGER NOT NULL CHECK(revision>=0)
  )''',
  'INSERT INTO library_meta VALUES(1,lower(hex(randomblob(16))),0)',
  'CREATE INDEX folders_page ON collection_folders(created_at,id)',
  'CREATE INDEX collection_page ON collection_items(folder_id,-added_at,source,content_id)',
  'CREATE INDEX collection_content_ref ON collection_items(source,content_id)',
  'CREATE INDEX later_page ON watch_later(done,-added_at,source,content_id)',
  'CREATE INDEX history_page ON content_history(-last_at,source,content_id,action)',
  'CREATE INDEX history_action_page ON content_history(action,-last_at,source,content_id)',
  'CREATE INDEX subscriptions_page ON local_subscriptions(-added_at,mid)',
  'CREATE INDEX follows_page ON calendar_follows(-followed_at,source,uid,recurrence_id)',
  for (final table in const {
    'content_refs': ['source', 'content_id', 'snapshot', 'updated_at'],
    'collection_folders': ['id', 'name', 'created_at'],
    'collection_items': ['folder_id', 'source', 'content_id', 'added_at'],
    'watch_later': ['source', 'content_id', 'added_at', 'done'],
    'content_history': ['source', 'content_id', 'action', 'last_at', 'visits'],
    'local_subscriptions': ['mid', 'name', 'avatar', 'added_at'],
    'calendar_follows': [
      'source',
      'uid',
      'recurrence_id',
      'snapshot',
      'sequence',
      'followed_at',
      'observed_at',
    ],
  }.entries)
    for (final operation in ['INSERT', 'UPDATE', 'DELETE'])
      '''CREATE TRIGGER ${table.key}_${operation.toLowerCase()}_revision
      AFTER $operation ON ${table.key}
      ${operation == 'UPDATE' ? 'WHEN ${table.value.map((c) => 'OLD.$c IS NOT NEW.$c').join(' OR ')}' : ''}
      BEGIN UPDATE library_meta SET revision=revision+1 WHERE singleton=1; END''',
];
