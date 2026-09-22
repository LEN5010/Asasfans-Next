/// Version 9 adds the in-app update inbox and its per-source cursors.
///
/// The inbox is a personal asset, not a cache. Read and archive state is the
/// user's own record of what they have dealt with, so it survives the source
/// dropping the item, a failed poll and a cleared network cache. Nothing here
/// is a delivered system notification: storing an update says the app saw it,
/// never that anyone was told.
final updatesSchemaV9 = <String>[
  // `id` is derived from the source's own identifiers (see UpdateIds), so a
  // second poll over unchanged source state collides on the primary key
  // instead of adding a duplicate row.
  '''CREATE TABLE update_events (
    id TEXT NOT NULL PRIMARY KEY,
    kind TEXT NOT NULL CHECK(kind IN ('subscriptionVideo','scheduleChange')),
    title TEXT NOT NULL,
    subtitle TEXT NOT NULL,
    occurred_at INTEGER NOT NULL CHECK(occurred_at >= 0),
    observed_at INTEGER NOT NULL CHECK(observed_at >= 0),
    source TEXT,
    content_id TEXT,
    creator_mid TEXT,
    creator_name TEXT,
    follow_source TEXT,
    follow_uid TEXT,
    follow_recurrence_id TEXT,
    schedule_change TEXT CHECK(schedule_change IS NULL OR schedule_change IN ('rescheduled','cancelled')),
    is_read INTEGER NOT NULL DEFAULT 0 CHECK(is_read IN (0,1)),
    archived_at INTEGER NOT NULL DEFAULT 0 CHECK(archived_at >= 0),
    -- A video update without the video it points at cannot be acted on, and a
    -- schedule change without its occurrence cannot be matched to a follow.
    CHECK((kind <> 'subscriptionVideo') OR (source IS NOT NULL AND content_id IS NOT NULL)),
    CHECK((kind <> 'scheduleChange') OR (follow_source IS NOT NULL AND follow_uid IS NOT NULL AND schedule_change IS NOT NULL))
  ) WITHOUT ROWID''',
  // Ordering is by when the thing happened at the source, never by when the
  // poll ran: a late collection pass must not reorder the inbox.
  'CREATE INDEX updates_inbox_page ON update_events(archived_at,-occurred_at,id)',
  'CREATE INDEX updates_unread_page ON update_events(is_read,archived_at,-occurred_at,id)',
  'CREATE INDEX updates_archived_page ON update_events(-archived_at,id)',
  // A bounded inbox, so a long-running store cannot grow without limit. Only
  // archived entries are dropped, oldest first: an unread or merely-read entry
  // is still something the user has not dealt with, and losing it silently
  // would be the inbox forgetting on its own.
  '''CREATE TRIGGER update_events_trim AFTER INSERT ON update_events
    WHEN (SELECT COUNT(*) FROM update_events) > 2000
    BEGIN
      DELETE FROM update_events WHERE id IN (
        SELECT id FROM update_events WHERE archived_at > 0
        ORDER BY archived_at, occurred_at, id
        LIMIT (SELECT COUNT(*) - 2000 FROM update_events)
      );
    END''',
  '''CREATE TABLE update_cursors (
    source_key TEXT NOT NULL PRIMARY KEY,
    baseline_at INTEGER NOT NULL CHECK(baseline_at >= 0),
    last_occurred_at INTEGER,
    last_id TEXT,
    CHECK((last_occurred_at IS NULL) = (last_id IS NULL))
  ) WITHOUT ROWID''',
  for (final table in const {
    'update_events': [
      'id',
      'kind',
      'title',
      'subtitle',
      'occurred_at',
      'observed_at',
      'is_read',
      'archived_at',
    ],
    'update_cursors': [
      'source_key',
      'baseline_at',
      'last_occurred_at',
      'last_id',
    ],
  }.entries)
    for (final operation in ['INSERT', 'UPDATE', 'DELETE'])
      '''CREATE TRIGGER ${table.key}_${operation.toLowerCase()}_revision
      AFTER $operation ON ${table.key}
      ${operation == 'UPDATE' ? 'WHEN ${table.value.map((c) => 'OLD.$c IS NOT NEW.$c').join(' OR ')}' : ''}
      BEGIN UPDATE library_meta SET revision=revision+1 WHERE singleton=1; END''',
];
