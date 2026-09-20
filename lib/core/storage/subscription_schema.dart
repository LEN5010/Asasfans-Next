/// Read receipts are personal assets, not playback progress. They deliberately
/// do not depend on a content cache or a currently subscribed creator.
final subscriptionSchemaV5 = <String>[
  '''CREATE TABLE subscription_reads (
    bvid TEXT NOT NULL PRIMARY KEY,
    is_read INTEGER NOT NULL CHECK(is_read IN (0,1)),
    updated_at INTEGER NOT NULL CHECK(updated_at>=0)
  ) WITHOUT ROWID''',
  '''CREATE TABLE subscription_meta (
    singleton INTEGER NOT NULL PRIMARY KEY CHECK(singleton=1),
    revision INTEGER NOT NULL CHECK(revision>=0)
  )''',
  'INSERT INTO subscription_meta VALUES(1,0)',
  for (final operation in ['INSERT', 'UPDATE', 'DELETE'])
    '''CREATE TRIGGER subscription_reads_${operation.toLowerCase()}_revision
      AFTER $operation ON subscription_reads
      ${operation == 'UPDATE' ? 'WHEN OLD.bvid IS NOT NEW.bvid OR OLD.is_read IS NOT NEW.is_read OR OLD.updated_at IS NOT NEW.updated_at' : ''}
      BEGIN UPDATE library_meta SET revision=revision+1 WHERE singleton=1; END''',
  for (final operation in ['INSERT', 'UPDATE', 'DELETE'])
    '''CREATE TRIGGER subscription_roster_${operation.toLowerCase()}
      AFTER $operation ON local_subscriptions
      ${operation == 'UPDATE' ? 'WHEN OLD.mid IS NOT NEW.mid OR OLD.name IS NOT NEW.name OR OLD.avatar IS NOT NEW.avatar OR OLD.added_at IS NOT NEW.added_at' : ''}
      BEGIN UPDATE subscription_meta SET revision=revision+1 WHERE singleton=1; END''',
];
