import '../helpers/library_fixture.dart';
import 'package:asasfans_next/shared/widgets/media_grid_delegate.dart';
import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/content/application/content_providers.dart';
import 'package:asasfans_next/features/content/domain/community_video_repository.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/features/content/presentation/content_page.dart';
import 'package:asasfans_next/features/content/presentation/fanart_filter_bar.dart';
import 'package:asasfans_next/features/content/presentation/fanart_card.dart';
import 'package:asasfans_next/features/content/presentation/fanart_detail_page.dart';
import 'package:asasfans_next/shared/widgets/app_page_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

FanartItem _item(String id) => FanartItem(
  identity: ContentIdentity(source: ContentSource.bilibiliDynamic, value: id),
  text: '作品 $id',
  authorName: '作者 $id',
  authorUid: '1',
  images: const [],
  kind: FanartKind.fanart,
  contentType: FanartContentType.image,
  category: FanartCategory.normal,
  characterTags: const [],
);

/// Serves deterministic pages without network access. Each page carries
/// `pageSize` items so the list is tall enough to scroll.
class _StubRepository implements FanartRepository {
  _StubRepository({this.pages = 3, this.pageSize = 24, this.failFirst = false});

  final int pages;
  final int pageSize;
  final bool failFirst;
  int requests = 0;
  int randomDraws = 0;
  final randomQueries = <FanartQuery>[];
  final List<FanartQuery> queries = [];
  final List<String?> cursors = [];

  @override
  Future<FanartItem?> random({
    FanartQuery query = const FanartQuery(),
    RequestCancellation? cancellation,
  }) async {
    randomDraws++;
    randomQueries.add(query);
    return _item('random-$randomDraws');
  }

  @override
  Future<FanartPage> page({
    FanartQuery query = const FanartQuery(),
    String? cursor,
    RequestCancellation? cancellation,
  }) async {
    requests++;
    queries.add(query);
    cursors.add(cursor);
    if (failFirst && cursor == null && requests == 1) {
      throw const ApiFailure(ApiFailureKind.offline);
    }
    final index = cursor == null ? 0 : int.parse(cursor);
    return FanartPage(
      items: [for (var i = 0; i < pageSize; i++) _item('p${index}i$i')],
      snapshotId: 'snap-1',
      nextCursor: index + 1 < pages ? '${index + 1}' : null,
    );
  }
}

Widget _app(FanartRepository repository) => ProviderScope(
  overrides: [
    ...offlineLibrary(),
    fanartRepositoryProvider.overrideWithValue(repository),
  ],
  child: const MaterialApp(home: ContentPage(channel: 'fanart')),
);

void main() {
  for (final width in [320.0, 1200.0]) {
    testWidgets(
      'toolbar and quick filters keep the first content row near the top at width $width',
      (tester) async {
        tester.view
          ..physicalSize = Size(width, 900)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_app(_StubRepository()));
        await tester.pumpAndSettle();
        expect(find.byType(AppBar), findsNothing);
        // The persistent chrome is the floating page bar; filters lead the
        // feed right under it. A new always-visible band fails here instead
        // of silently pushing content down.
        final toolbar = tester.getRect(find.byType(AppPageBar));
        expect(toolbar.height, lessThan(90));
        final filters = tester.getRect(find.byType(FanartFilterBar));
        expect(
          filters.top - toolbar.bottom,
          lessThan(8),
          reason: 'no band between them',
        );
        expect(filters.height, lessThan(64));
        final firstCard = tester.getTopLeft(find.byType(FanartCard).first).dy;
        expect(
          firstCard - filters.bottom,
          lessThan(72),
          reason: 'only grid padding separates the filters from the first row',
        );
        expect(
          find.byType(TextField),
          width >= 1040 ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'the fanart channel renders real items instead of a placeholder',
    (tester) async {
      await tester.pumpWidget(_app(_StubRepository()));
      await tester.pumpAndSettle();

      expect(find.text('即将开放'), findsNothing);
      expect(find.text('作品 p0i0'), findsOneWidget);
    },
  );

  testWidgets('a short first page fills a large viewport without any scroll', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1600, 1200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _StubRepository(pages: 3, pageSize: 1);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    expect(repository.requests, 3);
    expect(find.text('作品 p2i0'), findsOneWidget);
  });

  testWidgets(
    'an empty first page with a cursor continues to visible content',
    (tester) async {
      final repository = _EmptyFirstRepository();
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      expect(find.text('没有符合条件的内容'), findsNothing);
      expect(find.text('作品 visible'), findsOneWidget);
      expect(repository.requests, 2);
    },
  );

  testWidgets(
    'a failed refresh keeps cards and shows a retry instead of silently failing',
    (tester) async {
      final repository = _RefreshFailureRepository();
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ContentPage)),
      );
      await container
          .read(fanartFeedControllerProvider(ContentChannel.fanart))
          .refresh();
      await tester.pumpAndSettle();
      expect(find.text('作品 kept'), findsOneWidget);
      expect(find.text('刷新失败，网络连接失败'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '重试'), findsOneWidget);
    },
  );

  testWidgets('scrolling to the bottom appends the next page', (tester) async {
    final repository = _StubRepository();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    expect(repository.requests, 1);
    expect(find.text('作品 p1i0'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('作品 p1i0'),
      400,
      scrollable: find
          .descendant(
            of: find.byKey(const PageStorageKey('fanart-feed')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(repository.requests, greaterThan(1));
    expect(find.text('作品 p1i0'), findsOneWidget);
  });

  testWidgets('reaching the end shows a terminal state, not a spinner', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_StubRepository(pages: 1, pageSize: 2)));
    await tester.pumpAndSettle();

    expect(find.text('没有更多了'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('an empty dataset shows an empty state rather than an error', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_StubRepository(pages: 1, pageSize: 0)));
    await tester.pumpAndSettle();

    expect(find.text('没有符合条件的内容'), findsOneWidget);
  });

  testWidgets('a first page failure offers a retry that recovers', (
    tester,
  ) async {
    final repository = _StubRepository(failFirst: true, pages: 1);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.text('网络连接失败'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '重试'));
    await tester.pumpAndSettle();

    expect(find.text('作品 p0i0'), findsOneWidget);
  });

  testWidgets('the clips channel does not borrow the fanart dataset', (
    tester,
  ) async {
    final fanart = _StubRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...offlineLibrary(),
          fanartRepositoryProvider.overrideWithValue(fanart),
          communityVideoRepositoryProvider.overrideWithValue(
            _EmptyCommunityRepository(),
          ),
        ],
        child: const MaterialApp(home: ContentPage(channel: 'clips')),
      ),
    );
    await tester.pumpAndSettle();

    // Live clips come from the community video index; the fanart repository
    // must not be asked for them.
    expect(fanart.requests, 0);
    expect(find.text('作品 p0i0'), findsNothing);
  });

  testWidgets('applying a filter reloads with the new query from the top', (
    tester,
  ) async {
    final repository = _StubRepository();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    expect(repository.queries.last.characters, isEmpty);

    await tester.tap(find.widgetWithText(FilterChip, '嘉然'));
    await tester.pumpAndSettle();

    expect(repository.queries.last.characters, {FanartCharacter.diana});
    // A filter change starts a new run, so it must not carry an old cursor.
    expect(repository.cursors.last, isNull);
  });

  testWidgets('submitting a search applies the keyword', (tester) async {
    final repository = _StubRepository();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '嘉然');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(repository.queries.last.keyword, '嘉然');
  });

  testWidgets('the random draw opens a post directly', (tester) async {
    final repository = _StubRepository();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('随机二创'));
    await tester.pumpAndSettle();

    expect(repository.randomDraws, 1);
    expect(find.byType(FanartDetailPage), findsOneWidget);
    // A draw is independent of the list, which keeps its own pages.
    expect(find.text('作品 random-1'), findsOneWidget);
  });

  testWidgets(
    'random uses the current applied query rather than an unfiltered draw',
    (tester) async {
      final repository = _StubRepository();
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, '嘉然'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('搜索'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '生日');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('随机二创'));
      await tester.pumpAndSettle();
      expect(repository.randomQueries.single.keyword, '生日');
      expect(repository.randomQueries.single.characters, {
        FanartCharacter.diana,
      });
    },
  );

  testWidgets('the random action is absent on channels it cannot serve', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...offlineLibrary(),
          fanartRepositoryProvider.overrideWithValue(_StubRepository()),
          communityVideoRepositoryProvider.overrideWithValue(
            _EmptyCommunityRepository(),
          ),
        ],
        child: const MaterialApp(home: ContentPage(channel: 'clips')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('随机二创'), findsNothing);
  });

  testWidgets('a narrow window drops to one readable column', (tester) async {
    tester.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_StubRepository()));
    await tester.pumpAndSettle();

    final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
    final delegate = grid.gridDelegate as MediaGridDelegate;
    // 320 - 32 padding leaves room for one card above the readable floor.
    expect(delegate.crossAxisCount, 1);
  });

  testWidgets('wide windows use more columns than a phone', (tester) async {
    tester.view
      ..physicalSize = const Size(1600, 1200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_StubRepository()));
    await tester.pumpAndSettle();

    final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
    final delegate = grid.gridDelegate as MediaGridDelegate;
    expect(delegate.crossAxisCount, greaterThan(2));
  });
}

/// The clips channel must never reach the live community endpoint in a widget test.
class _EmptyCommunityRepository implements CommunityVideoRepository {
  @override
  Future<CommunityVideoPage> videos({
    CommunityVideoQuery query = const CommunityVideoQuery(),
    int page = 1,
    RequestCancellation? cancellation,
  }) async => CommunityVideoPage(videos: const [], page: page, hasMore: false);
}

class _EmptyFirstRepository extends _StubRepository {
  @override
  Future<FanartPage> page({
    FanartQuery query = const FanartQuery(),
    String? cursor,
    RequestCancellation? cancellation,
  }) async {
    requests++;
    return FanartPage(
      items: cursor == null ? [] : [_item('visible')],
      snapshotId: 's',
      nextCursor: cursor == null ? 'next' : null,
    );
  }
}

class _RefreshFailureRepository extends _StubRepository {
  @override
  Future<FanartPage> page({
    FanartQuery query = const FanartQuery(),
    String? cursor,
    RequestCancellation? cancellation,
  }) async {
    if (requests++ > 0) throw const ApiFailure(ApiFailureKind.offline);
    return FanartPage(items: [_item('kept')], snapshotId: 's');
  }
}
