/// Version 8 adds the return session behind an external open.
///
/// This is device-local run state, not a personal asset: it describes one trip
/// out to Bilibili and back. It is deliberately absent from the backup
/// allowlist — an active session restored onto another device would point at a
/// list that device was never showing.
///
/// Only one session is ever live, so the table is a singleton row. Keeping it
/// in SQLite rather than memory is what makes a cold return possible at all:
/// the process may not survive the trip.
final handoffSchemaV8 = <String>[
  '''CREATE TABLE return_sessions (
    singleton INTEGER NOT NULL PRIMARY KEY CHECK(singleton=1),
    session_id TEXT NOT NULL,
    target TEXT NOT NULL CHECK(target IN ('contentChannel','library','today')),
    channel TEXT,
    query TEXT NOT NULL,
    anchor TEXT NOT NULL,
    opened_source TEXT,
    opened_id TEXT,
    created_at INTEGER NOT NULL CHECK(created_at >= 0),
    -- A consumed session stays in the row rather than being deleted, so a
    -- repeated system callback can be recognised as already handled instead of
    -- looking like no session at all.
    consumed INTEGER NOT NULL DEFAULT 0 CHECK(consumed IN (0,1)),
    -- A content target needs to know which channel to return to; the other
    -- targets have no channel, and neither state may be half-specified.
    CHECK((target='contentChannel') = (channel IS NOT NULL)),
    CHECK((opened_source IS NULL) = (opened_id IS NULL))
  )''',
];
