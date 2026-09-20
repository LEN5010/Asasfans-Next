/// Version 7 adds saved query channels.
///
/// A channel stores a versioned semantic query, never a request URL: a saved
/// URL would freeze today's endpoint shape and silently break when the source
/// changes. `spec_version` lets a later reader migrate or reject an older
/// shape instead of guessing at its fields.
///
/// `feed` names which source the query belongs to, so a fanart channel can
/// never be replayed against the dynamics endpoint, whose parameters differ.
final channelSchemaV7 = <String>[
  '''CREATE TABLE saved_channels (
    id TEXT NOT NULL PRIMARY KEY,
    name TEXT NOT NULL,
    feed TEXT NOT NULL CHECK(feed IN ('fanart','dynamic','community')),
    spec_version INTEGER NOT NULL CHECK(spec_version >= 1),
    spec TEXT NOT NULL,
    position INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    UNIQUE(feed, name)
  )''',
  'CREATE INDEX channels_page ON saved_channels(position,id)',
  // A bounded list keeps the picker usable and the store small. The limit
  // matches the rules table's approach rather than inventing a new failure.
  '''CREATE TRIGGER channels_count_limit BEFORE INSERT ON saved_channels
    WHEN (SELECT COUNT(*) FROM saved_channels)>=200
    AND NOT EXISTS(SELECT 1 FROM saved_channels WHERE id=NEW.id)
    BEGIN SELECT RAISE(ABORT,'rule_limit'); END''',
  for (final action in ['INSERT', 'UPDATE', 'DELETE'])
    'CREATE TRIGGER saved_channels_${action.toLowerCase()}_revision AFTER $action ON saved_channels BEGIN UPDATE library_meta SET revision=revision+1 WHERE singleton=1; END',
];
