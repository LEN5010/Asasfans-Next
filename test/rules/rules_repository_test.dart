import 'package:asasfans_next/core/storage/local_database.dart';
import 'package:asasfans_next/core/storage/storage_failure.dart';
import 'package:asasfans_next/features/library/data/sqlite_library_repository.dart';
import 'package:asasfans_next/features/library/domain/library_models.dart';
import 'package:asasfans_next/features/rules/data/sqlite_rules_repository.dart';
import 'package:asasfans_next/features/rules/domain/content_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_fixture.dart';

void main() {
  late MemoryLocalDatabase db;
  late SqliteRulesRepository repo;
  setUp(() {
    db = MemoryLocalDatabase();
    repo = SqliteRulesRepository(db, clock: () => DateTime.utc(2026, 9, 21));
  });
  tearDown(() async {
    await repo.close();
    await db.close();
  });
  test(
    'new, duplicate and edited rules return reversible committed changes',
    () async {
      final first = await repo.save(
        const RuleDraft(kind: RuleKind.word, value: ' Hello '),
      );
      expect(first.before, isNull);
      expect(first.after!.draft.value, 'hello');
      final updated = await repo.save(
        const RuleDraft(kind: RuleKind.word, value: 'HELLO', enabled: false),
      );
      expect(updated.before!.id, first.after!.id);
      expect((await repo.load()).rules, hasLength(1));
      expect((await repo.load()).rules.single.draft.enabled, isFalse);
      expect(await repo.undo(updated), isTrue);
      expect((await repo.load()).rules.single.draft.enabled, isTrue);
      expect(await repo.undo(updated), isFalse);
    },
  );
  test(
    'same-clock concurrent edits and deletion undo never overwrite newer choices',
    () async {
      final first = (await repo.save(
        const RuleDraft(kind: RuleKind.word, value: 'first'),
      )).after!;
      final other = SqliteRulesRepository(db);
      addTearDown(other.close);
      final updated = await other.save(
        const RuleDraft(kind: RuleKind.word, value: 'new'),
        previous: first,
      );
      await expectLater(
        repo.save(
          const RuleDraft(kind: RuleKind.word, value: 'stale'),
          previous: first,
        ),
        throwsA(isA<RuleFailure>()),
      );
      final deleted = await repo.remove(updated.after!);
      await repo.save(const RuleDraft(kind: RuleKind.word, value: 'new'));
      expect(await repo.undo(deleted), isFalse);
      expect((await repo.load()).rules.single.draft.value, 'new');
    },
  );
  test(
    'removal and undo preserve enabled and expiry, creation undo removes only its own token',
    () async {
      final expires = DateTime.utc(2026, 10);
      final change = await repo.save(
        RuleDraft(kind: RuleKind.tag, value: 'Tag', expiresAt: expires),
      );
      final removed = await repo.remove(change.after!);
      expect(await repo.undo(removed), isTrue);
      final restored = (await repo.load()).rules.single;
      expect(restored.draft.expiresAt, expires);
      expect(await repo.undo(change), isFalse);
      final fresh = await repo.save(
        const RuleDraft(kind: RuleKind.tag, value: 'another'),
      );
      expect(await repo.undo(fresh), isTrue);
      expect((await repo.load()).rules, hasLength(1));
    },
  );
  test(
    'rule counts are bounded and existing rules remain editable at capacity',
    () async {
      await db.batch([
        const SqlStatement(
          '''WITH RECURSIVE n(i) AS(VALUES(1) UNION ALL SELECT i+1 FROM n WHERE i<1000)
      INSERT INTO content_rules(id,kind,scope,value,enabled,created_at,updated_at)
      SELECT lower(hex(randomblob(16))),'word','','word'||i,1,1,1 FROM n''',
        ),
      ], write: true);
      await expectLater(
        repo.save(const RuleDraft(kind: RuleKind.word, value: 'overflow')),
        throwsA(
          isA<RuleFailure>().having(
            (e) => e.kind,
            'kind',
            RuleFailureKind.limitReached,
          ),
        ),
      );
      final update = await repo.save(
        const RuleDraft(kind: RuleKind.word, value: 'word1', enabled: false),
      );
      expect(update.after!.draft.enabled, isFalse);
      expect((await repo.load()).rules, hasLength(1000));
    },
  );
  test(
    'invalid, duplicate-target and failed writes do not mutate existing rules',
    () async {
      final first = (await repo.save(
        const RuleDraft(kind: RuleKind.word, value: 'one'),
      )).after!;
      await repo.save(const RuleDraft(kind: RuleKind.word, value: 'two'));
      await expectLater(
        repo.save(
          const RuleDraft(kind: RuleKind.word, value: 'two'),
          previous: first,
        ),
        throwsA(isA<RuleFailure>()),
      );
      await expectLater(
        repo.save(
          const RuleDraft(
            kind: RuleKind.creator,
            value: 'not-uid',
            scope: 'bilibili',
          ),
        ),
        throwsA(isA<RuleFailure>()),
      );
      db.database.execute(
        "CREATE TRIGGER fail_rules BEFORE UPDATE ON content_rules BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      await expectLater(
        repo.save(
          const RuleDraft(kind: RuleKind.word, value: 'changed'),
          previous: first,
        ),
        throwsA(isA<StorageFailure>()),
      );
      expect((await repo.load()).rules.map((r) => r.draft.value).toSet(), {
        'one',
        'two',
      });
    },
  );
  test(
    'snapshot loads only subscription identities, and priority is genuinely durable',
    () async {
      final library = SqliteLibraryRepository(db);
      addTearDown(library.close);
      await library.subscribe(
        const LocalSubscription(mid: '123', name: 'name'),
      );
      expect((await repo.load()).subscriptions, {'123'});
      expect((await repo.load()).prioritizeSubscribed, isFalse);
      await repo.setSubscriptionPriority(true);
      final other = SqliteRulesRepository(db);
      addTearDown(other.close);
      expect((await other.load()).prioritizeSubscribed, isTrue);
      await repo.close();
      await expectLater(repo.load(), throwsA(isA<StorageFailure>()));
    },
  );
}
