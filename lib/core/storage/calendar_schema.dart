/// Structured calendar history and personal member subscriptions.
final calendarSchemaV10 = <String>[
  '''CREATE TABLE calendar_sources (
    calendar TEXT NOT NULL,
    origin TEXT NOT NULL CHECK(origin IN ('ics','api')),
    url TEXT NOT NULL,
    etag TEXT,
    last_modified TEXT,
    cursor TEXT,
    synced_at INTEGER,
    failed_at INTEGER,
    PRIMARY KEY(calendar,origin)
  ) WITHOUT ROWID''',
  '''CREATE TABLE calendar_events (
    calendar TEXT NOT NULL,
    uid TEXT NOT NULL,
    recurrence_id TEXT NOT NULL DEFAULT '',
    sequence INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL CHECK(status IN ('confirmed','tentative','cancelled')),
    all_day INTEGER NOT NULL CHECK(all_day IN (0,1)),
    start_ms INTEGER NOT NULL,
    end_ms INTEGER NOT NULL,
    start_date TEXT,
    end_date TEXT,
    title TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    location TEXT NOT NULL DEFAULT '',
    url TEXT,
    categories TEXT NOT NULL DEFAULT '[]',
    origin TEXT NOT NULL,
    first_seen INTEGER NOT NULL,
    last_seen INTEGER NOT NULL,
    gone_at INTEGER,
    PRIMARY KEY(calendar,uid,recurrence_id)
  ) WITHOUT ROWID''',
  'CREATE INDEX calendar_events_range ON calendar_events(calendar,start_ms)',
  '''CREATE TABLE calendar_member_follows (
    member TEXT NOT NULL PRIMARY KEY,
    followed_at INTEGER NOT NULL
  ) WITHOUT ROWID''',
  '''CREATE TABLE calendar_reminders (
    calendar TEXT NOT NULL,
    uid TEXT NOT NULL,
    recurrence_id TEXT NOT NULL,
    fire_at INTEGER NOT NULL,
    notification_id INTEGER NOT NULL UNIQUE,
    PRIMARY KEY(calendar,uid,recurrence_id)
  ) WITHOUT ROWID''',
  for (final operation in ['INSERT', 'UPDATE', 'DELETE'])
    '''CREATE TRIGGER calendar_member_follows_${operation.toLowerCase()}_revision
    AFTER $operation ON calendar_member_follows
    BEGIN UPDATE library_meta SET revision=revision+1 WHERE singleton=1; END''',
];
