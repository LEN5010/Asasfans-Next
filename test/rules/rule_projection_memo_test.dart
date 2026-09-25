import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/core/storage/storage_providers.dart';
import 'package:asasfans_next/features/library/application/library_providers.dart';
import 'package:asasfans_next/features/library/data/sqlite_library_repository.dart';
import 'package:asasfans_next/features/rules/application/rules_providers.dart';
import 'package:asasfans_next/features/rules/data/sqlite_rules_repository.dart';
import 'package:asasfans_next/features/rules/domain/content_rules.dart';
import 'package:asasfans_next/features/rules/presentation/rule_filter_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_fixture.dart';

int evaluations = 0;

RuleSubject _subject(String text) {
  evaluations++;
  return RuleSubject(
    identity: ContentIdentity(
      source: ContentSource.bilibiliDynamic,
      value: text,
    ),
    title: text,
    creatorScope: 'bilibili',
    creatorId: '1',
    creatorName: '作者',
  );
}

void main() {
  late MemoryLocalDatabase db;
  late SqliteRulesRepository rules;
  late SqliteLibraryRepository library;
  setUp(() {
    evaluations = 0;
    db = MemoryLocalDatabase();
    rules = SqliteRulesRepository(db);
    library = SqliteLibraryRepository(db, backgroundDecoding: false);
  });
  tearDown(() async {
    await rules.close();
    await library.close();
    await db.close();
  });

  testWidgets('same items and rules are projected once; changes re-project', (
    tester,
  ) async {
    final items = ValueNotifier<List<String>>(['甲', '乙', '丙']);
    final tick = ValueNotifier(0);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseProvider.overrideWithValue(db),
          rulesRepositoryProvider.overrideWithValue(rules),
          libraryRepositoryProvider.overrideWithValue(library),
        ],
        child: MaterialApp(
          home: ListenableBuilder(
            listenable: Listenable.merge([items, tick]),
            builder: (_, _) => RuleFilterScope<String>(
              items: items.value,
              subjectOf: _subject,
              builder: (visible) => Column(
                children: [for (final item in visible.items) Text(item)],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('乙'), findsOneWidget);
    final first = evaluations;
    expect(first, 3);

    // A parent rebuild with the same list (e.g. a status change) reuses it.
    tick.value++;
    await tester.pump();
    expect(evaluations, first);

    // A new page is a new list.
    items.value = [...items.value, '丁'];
    await tester.pump();
    expect(evaluations, first + 4);
    expect(find.text('丁'), findsOneWidget);

    // A rule edit is a new rules state and applies at once.
    await rules.save(const RuleDraft(kind: RuleKind.word, value: '乙'));
    await tester.pumpAndSettle();
    expect(find.text('乙'), findsNothing);
    expect(find.text('甲'), findsOneWidget);
  });
}
