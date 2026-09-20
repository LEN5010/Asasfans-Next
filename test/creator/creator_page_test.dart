import 'package:asasfans_next/app/providers.dart';
import 'package:asasfans_next/core/platform/external_link_service.dart';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/core/storage/local_database.dart';
import 'package:asasfans_next/core/storage/storage_failure.dart';
import 'package:asasfans_next/core/storage/storage_providers.dart';
import 'package:asasfans_next/features/library/data/sqlite_library_repository.dart';
import 'package:asasfans_next/features/creator/application/creator_providers.dart';
import 'package:asasfans_next/features/creator/domain/creator_repository.dart';
import 'package:asasfans_next/features/creator/presentation/creator_page.dart';
import 'package:asasfans_next/features/creator/presentation/creator_link.dart';
import 'package:asasfans_next/features/library/application/library_providers.dart';
import 'package:asasfans_next/features/rules/application/rules_providers.dart';
import 'package:asasfans_next/features/rules/domain/content_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/creator_fixture.dart';
import '../helpers/library_fixture.dart';
import '../helpers/sqlite_fixture.dart';

class _Links implements ExternalLinkService {
  final opened = <Uri>[];
  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}

class _WriteGate implements LocalDatabase {
  final inner = MemoryLocalDatabase();
  bool fail = false;
  @override
  Future<SqlResults> batch(List<SqlStatement> commands, {bool write = false}) {
    if (write && fail) {
      return Future.error(const StorageFailure(StorageFailureKind.unavailable));
    }
    return inner.batch(commands, write: write);
  }

  @override
  Future<void> close() => inner.close();
}

void main() {
  late OfflineCreatorRepository repository;
  late _Links links;
  setUp(() {
    repository = OfflineCreatorRepository();
    links = _Links();
  });
  Widget host({double scale = 1, Widget? page}) => ProviderScope(
    overrides: [
      ...offlineLibrary(),
      creatorRepositoryProvider.overrideWithValue(repository),
      externalLinkServiceProvider.overrideWithValue(links),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: page ?? const CreatorPage(mid: '123'),
    ),
  );

  testWidgets(
    'profile details, committed local subscription and explicit B-site link',
    (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expect(find.text('个人简介'), findsOneWidget);
      expect(find.text('还没有投稿'), findsOneWidget);
      expect(links.opened, isEmpty);
      await tester.tap(find.text('本地订阅'));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CreatorPage)),
      );
      expect(
        await container.read(libraryRepositoryProvider).isSubscribed('123'),
        isTrue,
      );
      expect(find.text('已订阅'), findsOneWidget);
      await tester.tap(find.byTooltip('在 B 站打开 UP 主页'));
      await tester.pumpAndSettle();
      expect(links.opened, [Uri.https('space.bilibili.com', '/123')]);
      expect(
        await container.read(libraryRepositoryProvider).history(),
        isEmpty,
      );
    },
  );
  testWidgets(
    'archive failure is independent, not fake empty and retry does not refetch profile',
    (tester) async {
      repository.onArchives = (_, _) async =>
          throw const ApiFailure(ApiFailureKind.riskControl);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expect(find.text('个人简介'), findsOneWidget);
      expect(find.text('还没有投稿'), findsNothing);
      expect(find.textContaining('B 站暂时拦截'), findsOneWidget);
      repository.onArchives = (_, page) async => CreatorArchivePage(
        items: [creatorVideo(1)],
        page: page,
        total: 1,
        hasMore: false,
      );
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('投稿 1'), findsOneWidget);
      expect(repository.profileCalls, 1);
    },
  );
  testWidgets(
    'subscription write failure never reports subscribed and can retry',
    (tester) async {
      final db = _WriteGate();
      final library = SqliteLibraryRepository(db, backgroundDecoding: false);
      addTearDown(() async {
        await library.close();
        await db.close();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localDatabaseProvider.overrideWithValue(db),
            libraryRepositoryProvider.overrideWithValue(library),
            creatorRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(home: CreatorPage(mid: '123')),
        ),
      );
      await tester.pumpAndSettle();
      db.fail = true;
      await tester.tap(find.text('本地订阅'));
      await tester.pumpAndSettle();
      expect(find.text('已订阅'), findsNothing);
      expect(await library.isSubscribed('123'), isFalse);
      expect(find.text('本地资料暂时无法读写，请重试'), findsOneWidget);
      db.fail = false;
      await tester.tap(find.text('本地订阅'));
      await tester.pumpAndSettle();
      expect(find.text('已订阅'), findsOneWidget);
      expect(await library.isSubscribed('123'), isTrue);
    },
  );
  testWidgets(
    'blocked first page autofills from raw cursor; undo restores without HTTP',
    (tester) async {
      repository.onArchives = (_, page) async => CreatorArchivePage(
        items: page == 1
            ? List.generate(30, (i) => creatorVideo(i, title: 'hide $i'))
            : [creatorVideo(31)],
        page: page,
        total: 31,
        hasMore: page == 1,
      );
      final container = ProviderContainer(
        overrides: [
          ...offlineLibrary(),
          creatorRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final rules = container.read(rulesRepositoryProvider);
      final change = await rules.save(
        const RuleDraft(kind: RuleKind.word, value: 'hide'),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: CreatorPage(mid: '123')),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.archiveQueries.map((request) => request.$2), [1, 2]);
      expect(find.text('投稿 31'), findsOneWidget);
      expect(find.text('hide 0'), findsNothing);
      await rules.undo(change);
      await tester.pumpAndSettle();
      expect(find.text('hide 0'), findsOneWidget);
      expect(repository.archiveQueries, hasLength(2));
    },
  );
  testWidgets(
    'query and sort reset archives only; author link is native root route',
    (tester) async {
      await tester.pumpWidget(
        host(
          page: const Scaffold(
            body: CreatorLink(mid: '123', child: Text('作者入口')),
          ),
        ),
      );
      await tester.tap(find.text('作者入口'));
      await tester.pumpAndSettle();
      expect(find.byType(CreatorPage), findsOneWidget);
      expect(links.opened, isEmpty);
      await tester.tap(find.widgetWithText(ChoiceChip, '播放'));
      await tester.pumpAndSettle();
      expect(
        repository.archiveQueries.last.$1.order,
        CreatorArchiveOrder.mostViewed,
      );
      await tester.tap(find.byTooltip('搜索'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '嘉然');
      await tester.tap(find.widgetWithText(FilledButton, '搜索'));
      await tester.pumpAndSettle();
      expect(repository.archiveQueries.last.$1.keyword, '嘉然');
      expect(repository.profileCalls, 1);
    },
  );
  testWidgets('many hidden pages stop at the shared automatic budget', (
    tester,
  ) async {
    repository.onArchives = (_, page) async => CreatorArchivePage(
      items: List.generate(
        30,
        (index) => creatorVideo(page * 30 + index, title: 'hide $page $index'),
      ),
      page: page,
      total: 180,
      hasMore: page < 6,
    );
    final container = ProviderContainer(
      overrides: [
        ...offlineLibrary(),
        creatorRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(rulesRepositoryProvider)
        .save(const RuleDraft(kind: RuleKind.word, value: 'hide'));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CreatorPage(mid: '123')),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.archiveQueries.length, 5);
    expect(find.text('继续加载'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(repository.archiveQueries.length, 5);
    await tester.tap(find.text('继续加载'));
    await tester.pumpAndSettle();
    expect(repository.archiveQueries.length, 6);
    expect(find.text('当前投稿已被屏蔽'), findsOneWidget);
  });
  testWidgets(
    'same author does not stack another route; collaboration can open its actual author',
    (tester) async {
      repository.onArchives = (query, page) async => CreatorArchivePage(
        items: [
          creatorVideo(1, mid: query.mid),
          creatorVideo(2, mid: '456'),
        ],
        page: page,
        total: 2,
        hasMore: false,
      );
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      final ownLink = find.ancestor(
        of: find.text('作者 123'),
        matching: find.byType(CreatorLink),
      );
      expect(
        find.descendant(of: ownLink, matching: find.byType(InkWell)),
        findsNothing,
      );
      await tester.ensureVisible(find.text('作者 456'));
      await tester.tap(find.text('作者 456'));
      await tester.pumpAndSettle();
      expect(tester.widget<CreatorPage>(find.byType(CreatorPage)).mid, '456');
      expect(repository.profileCalls, 2);
      expect(links.opened, isEmpty);
    },
  );
  for (final size in [const Size(320, 568), const Size(1280, 800)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('profile/grid long text at $size scale $scale', (
        tester,
      ) async {
        tester.view
          ..physicalSize = size
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        repository.onProfile = (mid) async => CreatorProfile(
          mid: mid,
          name: '长名称' * 20,
          signature: '长简介\n' * 20,
          official: '认证介绍' * 20,
          followers: 12345,
        );
        repository.onArchives = (_, page) async => CreatorArchivePage(
          items: [creatorVideo(1, title: '长视频标题' * 20)],
          page: page,
          total: 1,
          hasMore: false,
        );
        await tester.pumpWidget(host(scale: scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.drag(
          find.byType(CustomScrollView).first,
          const Offset(0, -1500),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
