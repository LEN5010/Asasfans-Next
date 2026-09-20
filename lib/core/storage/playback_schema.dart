/// Version 6 adds playback continuity: per-part progress and time bookmarks.
///
/// Both tables key a part by its Bilibili CID, never by an episode index: the
/// source may reorder parts, and a stored index would silently point at another
/// part. Positions and durations are milliseconds in 64-bit integers; the API's
/// seconds are converted at the mapping layer, not here.
///
/// A row here means the user has watch state worth keeping, so both tables join
/// `content_refs` and participate in pruning — progress alone keeps a snapshot
/// alive even after the item leaves every folder, watch-later and history list.
final playbackSchemaV6 = <String>[
  // position_ms <= duration_ms only when the duration is known: an unknown
  // duration is 0 and must not clamp a real position to zero.
  '''CREATE TABLE playback_progress (
    source TEXT NOT NULL, content_id TEXT NOT NULL, part_id TEXT NOT NULL,
    position_ms INTEGER NOT NULL CHECK(position_ms >= 0),
    duration_ms INTEGER NOT NULL DEFAULT 0 CHECK(duration_ms >= 0),
    completed INTEGER NOT NULL DEFAULT 0 CHECK(completed IN (0,1)),
    updated_at INTEGER NOT NULL,
    CHECK(duration_ms = 0 OR position_ms <= duration_ms),
    PRIMARY KEY(source, content_id, part_id),
    FOREIGN KEY(source, content_id) REFERENCES content_refs(source, content_id)
  ) WITHOUT ROWID''',
  // end_ms is an optional range: NULL is a point bookmark, not a zero-length
  // one. A present end must lie at or after the start.
  '''CREATE TABLE playback_bookmarks (
    id TEXT NOT NULL PRIMARY KEY,
    source TEXT NOT NULL, content_id TEXT NOT NULL, part_id TEXT NOT NULL,
    start_ms INTEGER NOT NULL CHECK(start_ms >= 0),
    end_ms INTEGER CHECK(end_ms IS NULL OR end_ms >= start_ms),
    title TEXT NOT NULL, note TEXT NOT NULL DEFAULT '',
    created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
    FOREIGN KEY(source, content_id) REFERENCES content_refs(source, content_id)
  ) WITHOUT ROWID''',
  'CREATE INDEX progress_page ON playback_progress(-updated_at,source,content_id,part_id)',
  'CREATE INDEX progress_resume ON playback_progress(completed,-updated_at,source,content_id,part_id)',
  'CREATE INDEX bookmarks_page ON playback_bookmarks(-created_at,id)',
  // Ordering bookmarks inside one part is by time, then by id for determinism.
  'CREATE INDEX bookmarks_part ON playback_bookmarks(source,content_id,part_id,start_ms,id)',
  'CREATE INDEX bookmarks_content_ref ON playback_bookmarks(source,content_id)',
  for (final table in const {
    'playback_progress': [
      'source',
      'content_id',
      'part_id',
      'position_ms',
      'duration_ms',
      'completed',
      'updated_at',
    ],
    'playback_bookmarks': [
      'id',
      'source',
      'content_id',
      'part_id',
      'start_ms',
      'end_ms',
      'title',
      'note',
      'created_at',
      'updated_at',
    ],
  }.entries)
    for (final operation in ['INSERT', 'UPDATE', 'DELETE'])
      '''CREATE TRIGGER ${table.key}_${operation.toLowerCase()}_revision
      AFTER $operation ON ${table.key}
      ${operation == 'UPDATE' ? 'WHEN ${table.value.map((c) => 'OLD.$c IS NOT NEW.$c').join(' OR ')}' : ''}
      BEGIN UPDATE library_meta SET revision=revision+1 WHERE singleton=1; END''',
];
