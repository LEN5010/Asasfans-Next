import 'package:asasfans_next/core/storage/storage_failure.dart';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/content/presentation/content_page.dart';
import 'package:asasfans_next/features/library/application/library_providers.dart';
import 'package:asasfans_next/features/rules/application/rules_providers.dart';
import 'package:asasfans_next/features/rules/domain/content_rules.dart';
import 'package:asasfans_next/features/subscriptions/application/subscription_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/library_fixture.dart';
import '../helpers/subscriptions_fixture.dart';

void main() {
  late UpdateSource source;
  late MemoryUpdateStore store;
  setUp(() {
    source = UpdateSource()..rows['123'] = [updateVideo(1), updateVideo(2)];
    store = MemoryUpdateStore(['123']);
  });
  tearDown(() => store.close());
  Widget host({double scale = 1}) => ProviderScope(
    overrides: [
      ...offlineLibrary(),
      subscriptionUpdateStoreProvider.overrideWithValue(store),
      subscriptionArchiveSourceProvider.overrideWithValue(source),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: const ContentPage(channel: 'subscriptions'),
    ),
  );
  testWidgets(
    'real feed channel, committed read/unread state and no fabricated playback',
    (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expect(find.text('更新 1'), findsOneWidget);
      expect(find.text('更新 2'), findsOneWidget);
      final button = find.text('标为已读').first;
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(store.reads[updateVideo(1).identity.value], isTrue);
      await tester.tap(find.widgetWithText(ChoiceChip, '未读'));
      await tester.pumpAndSettle();
      expect(find.text('更新 1'), findsNothing);
      expect(find.text('更新 2'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ContentPage)),
      );
      expect(
        await container.read(libraryRepositoryProvider).history(),
        isEmpty,
      );
    },
  );
  testWidgets(
    'failed writes retain unread; bulk action only marks frozen currently loaded visible IDs',
    (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      store.writeFailure = const StorageFailure(StorageFailureKind.unavailable);
      await tester.ensureVisible(find.text('标为已读').first);
      await tester.tap(find.text('标为已读').first);
      await tester.pumpAndSettle();
      expect(store.reads, isEmpty);
      store.writeFailure = null;
      await tester.tap(find.text('标记当前已读'));
      await tester.pumpAndSettle();
      expect(find.text('标记这 2 条更新为已读？'), findsOneWidget);
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(store.reads.length, 2);
      expect(store.reads[updateVideo(99).identity.value], isNull);
    },
  );
  testWidgets(
    'failed UP is visible but healthy posts remain; retry is explicit',
    (tester) async {
      store.snapshot = updateRoster(['123', '456']);
      source.failures['456'] = const ApiFailure(ApiFailureKind.riskControl);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expect(find.text('更新 1'), findsOneWidget);
      expect(find.text('1 位 UP 加载失败'), findsOneWidget);
      final count = source.calls.length;
      await tester.pump(const Duration(seconds: 1));
      expect(source.calls.length, count);
      await tester.tap(find.text('1 位 UP 加载失败'));
      await tester.pumpAndSettle();
      expect(find.textContaining('B 站暂时拦截'), findsOneWidget);
      source.failures.clear();
      source.rows['456'] = [updateVideo(3)];
      await tester.tap(find.text('重新检查'));
      await tester.pumpAndSettle();
      expect(find.text('更新 3'), findsOneWidget);
      expect(source.calls.where((c) => c.$1 == '123'), hasLength(1));
    },
  );
  testWidgets(
    'unknown receipt state never claims there are no unread updates',
    (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '未读'));
      store.readFailure = const StorageFailure(StorageFailureKind.unavailable);
      store.events.add(1);
      await tester.pumpAndSettle();
      expect(find.text('已读状态读取失败'), findsOneWidget);
      expect(find.text('没有未读更新'), findsNothing);
      expect(find.text('未读状态暂不可用'), findsOneWidget);
      store.readFailure = null;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('更新 1'), findsOneWidget);
      expect(source.calls, hasLength(1));
    },
  );
  testWidgets(
    'rules filter presentation only, raw multi-page frontier still refills',
    (tester) async {
      source.rows['123'] = [
        ...List.generate(30, (i) => updateVideo(i, title: 'hide $i')),
        updateVideo(31),
      ];
      final container = ProviderContainer(
        overrides: [
          ...offlineLibrary(),
          subscriptionUpdateStoreProvider.overrideWithValue(store),
          subscriptionArchiveSourceProvider.overrideWithValue(source),
        ],
      );
      addTearDown(container.dispose);
      final change = await container
          .read(rulesRepositoryProvider)
          .save(const RuleDraft(kind: RuleKind.word, value: 'hide'));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ContentPage(channel: 'subscriptions')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('更新 31'), findsOneWidget);
      expect(source.calls, contains(('123', 2)));
      final calls = source.calls.length;
      await container.read(rulesRepositoryProvider).undo(change);
      await tester.pumpAndSettle();
      expect(find.text('hide 0'), findsOneWidget);
      expect(source.calls.length, calls);
    },
  );
  for (final size in [const Size(320, 568), const Size(1280, 800)]) {
    testWidgets(
      'subscription toolbar and receipt cards at $size with large text',
      (tester) async {
        tester.view
          ..physicalSize = size
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(host(scale: 2));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
