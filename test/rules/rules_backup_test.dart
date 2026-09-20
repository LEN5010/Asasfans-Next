import 'dart:convert';
import 'dart:typed_data';

import 'package:asasfans_next/core/storage/local_database.dart';
import 'package:asasfans_next/core/storage/storage_failure.dart';
import 'package:asasfans_next/features/backup/data/backup_codec.dart';
import 'package:asasfans_next/features/backup/data/sqlite_backup_repository.dart';
import 'package:asasfans_next/features/backup/domain/personal_backup.dart';
import 'package:asasfans_next/features/rules/data/sqlite_rules_repository.dart';
import 'package:asasfans_next/features/rules/domain/content_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_fixture.dart';

Uint8List _encode(Object value) =>
    Uint8List.fromList(utf8.encode(jsonEncode(value)));
void main() {
  late MemoryLocalDatabase db;
  late SqliteRulesRepository rules;
  late SqliteBackupRepository backups;
  setUp(() {
    db = MemoryLocalDatabase();
    rules = SqliteRulesRepository(db);
    backups = SqliteBackupRepository(db, onCommitted: () {});
  });
  tearDown(() async {
    await rules.close();
    await db.close();
  });
  test(
    'the current format exports rules without undo tokens and preserves local conflicts on repeated merge',
    () async {
      final saved = await rules.save(
        const RuleDraft(kind: RuleKind.word, value: 'word'),
      );
      await rules.setSubscriptionPriority(false);
      final bytes = await backups.export();
      final raw = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      expect(raw['version'], BackupCodec.formatVersion);
      expect(utf8.decode(bytes), isNot(contains('change_token')));
      final target = MemoryLocalDatabase();
      final targetRules = SqliteRulesRepository(target);
      addTearDown(() async {
        await targetRules.close();
        await target.close();
      });
      final restore = SqliteBackupRepository(target, onCommitted: () {});
      final file = await restore.inspect(bytes);
      await restore.merge(file);
      expect((await targetRules.load()).rules.single.id, saved.after!.id);
      expect(
        (await targetRules.load()).rules.single.changeToken,
        isNot(saved.after!.changeToken),
      );
      expect((await targetRules.load()).prioritizeSubscribed, isFalse);
      await targetRules.save(
        const RuleDraft(kind: RuleKind.word, value: 'word', enabled: false),
      );
      await targetRules.setSubscriptionPriority(true);
      await restore.merge(file);
      expect((await targetRules.load()).rules.single.draft.enabled, isFalse);
      expect((await targetRules.load()).prioritizeSubscribed, isTrue);
    },
  );
  test(
    'legacy v1 remains readable, omits new tables and does not erase current rules',
    () async {
      await rules.save(const RuleDraft(kind: RuleKind.tag, value: '嘉然'));
      final raw =
          jsonDecode(utf8.decode(await backups.export()))
              as Map<String, dynamic>;
      raw['version'] = 1;
      (raw['data'] as Map<String, dynamic>)
        ..remove('content_rules')
        ..remove('rule_settings')
        ..remove('subscription_reads');
      final file = await backups.inspect(_encode(raw));
      expect(file.summary.counts['content_rules'], 0);
      await backups.merge(file);
      expect((await rules.load()).rules, hasLength(1));
    },
  );
  test(
    'backup rejects unscoped identifiers, unknown settings and duplicate normalized rules',
    () async {
      await rules.save(const RuleDraft(kind: RuleKind.word, value: 'word'));
      final original = await backups.export();
      final mutations = <void Function(Map<String, dynamic>)>[
        (r) => r['data']['content_rules'][0]['scope'] = 'bilibili',
        (r) => r['data']['content_rules'][0]['value'] = ' WORD ',
        (r) => r['data']['content_rules'][0]['id'] = 'builtin:carol',
        (r) => r['data']['content_rules'][0]['change_token'] = '0' * 32,
        (r) => r['data']['rule_settings'].add({
          'key': 'unsupported',
          'value': 'true',
        }),
        (r) => r['data']['content_rules'].add({
          ...r['data']['content_rules'][0] as Map<String, dynamic>,
          'id': 'f' * 32,
        }),
      ];
      for (final mutate in mutations) {
        final raw = jsonDecode(utf8.decode(original)) as Map<String, dynamic>;
        mutate(raw);
        expect(
          () => BackupCodec.decode(_encode(raw)),
          throwsA(isA<BackupFailure>()),
        );
      }
    },
  );
  test(
    'combined rule capacity failure rolls back earlier imported preferences',
    () async {
      await rules.save(const RuleDraft(kind: RuleKind.word, value: 'new'));
      await db.batch([
        const SqlStatement(
          "INSERT INTO preferences VALUES('appearance','dark')",
        ),
      ], write: true);
      final file = await backups.inspect(await backups.export());
      final target = MemoryLocalDatabase();
      addTearDown(target.close);
      await target.batch([
        const SqlStatement(
          '''WITH RECURSIVE n(i) AS(VALUES(1) UNION ALL SELECT i+1 FROM n WHERE i<1000)
      INSERT INTO content_rules(id,kind,scope,value,enabled,created_at,updated_at)
      SELECT lower(hex(randomblob(16))),'word','','existing'||i,1,1,1 FROM n''',
        ),
      ], write: true);
      final importer = SqliteBackupRepository(
        target,
        onCommitted: () => fail('must not notify an aborted import'),
      );
      await expectLater(
        importer.merge(file),
        throwsA(
          isA<StorageFailure>().having(
            (e) => e.kind,
            'kind',
            StorageFailureKind.capacity,
          ),
        ),
      );
      expect(target.database.select('SELECT * FROM preferences'), isEmpty);
      expect(
        target.database
            .select('SELECT count(*) AS n FROM content_rules')
            .single['n'],
        1000,
      );
    },
  );
  test(
    'v3 to v4 adds rules without losing existing personal records',
    () async {
      removeSubscriptionV5Fixture(db.database);
      db.database.execute('DROP TABLE content_rules');
      db.database.execute('DROP TABLE rule_settings');
      db.database.userVersion = 3;
      db.database.execute(
        "INSERT INTO local_subscriptions VALUES('123','retained',NULL,1)",
      );
      final id = db.database
          .select('SELECT store_id FROM library_meta')
          .single['store_id'];
      SqliteExecutor.initialize(db.database);
      expect(db.database.userVersion, SqliteExecutor.schemaVersion);
      expect(
        db.database
            .select('SELECT store_id FROM library_meta')
            .single['store_id'],
        id,
      );
      expect(
        db.database
            .select('SELECT name FROM local_subscriptions')
            .single['name'],
        'retained',
      );
      expect((await rules.load()).rules, isEmpty);
    },
  );
}
