import 'package:asasfans_next/core/storage/local_database.dart';
import 'package:asasfans_next/core/storage/storage_failure.dart';
import 'package:asasfans_next/core/storage/storage_providers.dart';
import 'package:asasfans_next/features/rules/application/rules_providers.dart';
import 'package:asasfans_next/features/rules/data/sqlite_rules_repository.dart';
import 'package:asasfans_next/features/rules/domain/content_rules.dart';
import 'package:asasfans_next/features/rules/presentation/rules_page.dart';
import 'package:flutter/material.dart';
import 'package:asasfans_next/shared/widgets/glass/app_glass_controls.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_fixture.dart';

class _Writes implements LocalDatabase {
  _Writes(this.inner);
  final LocalDatabase inner;
  bool fail = false;
  @override
  Future<SqlResults> batch(
    List<SqlStatement> statements, {
    bool write = false,
  }) {
    if (write && fail) {
      return Future.error(const StorageFailure(StorageFailureKind.unavailable));
    }
    return inner.batch(statements, write: write);
  }

  @override
  Future<void> close() => inner.close();
}

void main() {
  late MemoryLocalDatabase db;
  late _Writes writes;
  late SqliteRulesRepository repository;
  setUp(() {
    db = MemoryLocalDatabase();
    writes = _Writes(db);
    repository = SqliteRulesRepository(writes);
  });
  tearDown(() async {
    await repository.close();
    await db.close();
  });
  Widget host({double scale = 1}) => ProviderScope(
    overrides: [
      localDatabaseProvider.overrideWithValue(writes),
      rulesRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: const RulesPage(),
    ),
  );
  testWidgets('UI UX: user rules retain commit and undo without builtin copy', (
    tester,
  ) async {
    await repository.save(const RuleDraft(kind: RuleKind.word, value: '测试词'));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.textContaining('Carol'), findsNothing);
    expect(find.text('视频默认过滤'), findsNothing);
    writes.fail = true;
    await tester.tap(find.byType(AppGlassSwitch).last);
    await tester.pumpAndSettle();
    expect((await repository.load()).rules.single.draft.enabled, isTrue);
    expect(
      tester.widget<AppGlassSwitch>(find.byType(AppGlassSwitch).last).value,
      isTrue,
    );
    expect(find.text('本地资料暂时无法读写，请重试'), findsOneWidget);
    // Clear it before acting again: the delete queues its own snackbar behind
    // this one, and settling would run both lifetimes out, taking the undo
    // action away before it can be tapped.
    ScaffoldMessenger.of(
      tester.element(find.byType(AppGlassSwitch).last),
    ).removeCurrentSnackBar();
    await tester.pumpAndSettle();
    writes.fail = false;
    await tester.tap(find.byTooltip('删除规则'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
    expect((await repository.load()).rules, isEmpty);
    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();
    expect((await repository.load()).rules.single.draft.value, '测试词');
  });
  testWidgets(
    'editor refuses empty rule then saves normalized input with a real value',
    (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('添加规则'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.text('规则内容无效，请检查'), findsOneWidget);
      await tester.enterText(find.byType(TextField), ' HELLO ');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect((await repository.load()).rules.single.draft.value, 'hello');
    },
  );
  for (final size in const [Size(320, 568), Size(1200, 800)]) {
    testWidgets('rules manager and editor fit ${size.width} with large text', (
      tester,
    ) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await repository.save(
        const RuleDraft(kind: RuleKind.word, value: '这是用于检查长字段与窄窗的屏蔽词'),
      );
      await tester.pumpWidget(host(scale: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('添加规则'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
