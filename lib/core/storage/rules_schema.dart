final rulesSchemaV4 = <String>[
  '''CREATE TABLE content_rules (
    id TEXT NOT NULL PRIMARY KEY,
    kind TEXT NOT NULL CHECK(kind IN ('content','creator','word','tag')),
    scope TEXT NOT NULL, value TEXT NOT NULL,
    enabled INTEGER NOT NULL CHECK(enabled IN (0,1)), expires_at INTEGER,
    created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
    change_token TEXT NOT NULL DEFAULT (lower(hex(randomblob(16)))),
    UNIQUE(kind,scope,value)
  )''',
  '''CREATE TABLE rule_settings (
    key TEXT NOT NULL PRIMARY KEY CHECK(key='subscribed_first'),
    value TEXT NOT NULL CHECK(value IN ('true','false'))
  ) WITHOUT ROWID''',
  '''CREATE TRIGGER rules_count_limit BEFORE INSERT ON content_rules
    WHEN (SELECT COUNT(*) FROM content_rules)>=1000
    AND NOT EXISTS(SELECT 1 FROM content_rules WHERE id=NEW.id OR (kind=NEW.kind AND scope=NEW.scope AND value=NEW.value))
    BEGIN SELECT RAISE(ABORT,'rule_limit'); END''',
  for (final table in ['content_rules', 'rule_settings'])
    for (final action in ['INSERT', 'UPDATE', 'DELETE'])
      'CREATE TRIGGER ${table}_${action.toLowerCase()}_revision AFTER $action ON $table BEGIN UPDATE library_meta SET revision=revision+1 WHERE singleton=1; END',
];
