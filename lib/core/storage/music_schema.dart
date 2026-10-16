/// Songs the user keeps. Each row carries the song as the catalogue showed it,
/// so the list still reads when the catalogue cannot be fetched.
final musicSchemaV11 = <String>[
  '''CREATE TABLE music_favorites (
    song_id TEXT NOT NULL PRIMARY KEY,
    snapshot TEXT NOT NULL,
    added_at INTEGER NOT NULL
  ) WITHOUT ROWID''',
  'CREATE INDEX music_favorites_page ON music_favorites(-added_at,song_id)',
  for (final operation in ['INSERT', 'UPDATE', 'DELETE'])
    '''CREATE TRIGGER music_favorites_${operation.toLowerCase()}_revision
    AFTER $operation ON music_favorites
    BEGIN UPDATE library_meta SET revision=revision+1 WHERE singleton=1; END''',
];
