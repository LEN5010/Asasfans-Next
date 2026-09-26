import '../helpers/library_fixture.dart';
import 'package:asasfans_next/shared/widgets/app_controls.dart';
import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/content/application/content_providers.dart';
import 'package:asasfans_next/features/content/domain/community_video_repository.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/features/content/domain/dynamic_repository.dart';
import 'package:asasfans_next/features/content/presentation/dynamic_feed_view.dart';
import 'package:asasfans_next/features/novels/presentation/novel_feed_view.dart';
import 'package:asasfans_next/features/novels/application/novel_providers.dart';
import 'package:asasfans_next/features/novels/domain/novel_repository.dart';
import 'package:asasfans_next/features/content/presentation/content_page.dart';
import 'package:asasfans_next/features/content/presentation/fanart_filter_bar.dart';
import 'package:asasfans_next/features/content/presentation/content_search_control.dart';
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
  testWidgets(
    'Density: fanart stays compact across widths and menus remain usable',
    (tester) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = _StubRepository(pages: 1);
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(FanartCard).first).width,
        lessThan(200),
      );
      expect(
        tester.getTopLeft(find.byType(FanartCard).at(1)).dx,
        greaterThan(tester.getTopLeft(find.byType(FanartCard).first).dx),
      );
      expect(find.byType(FanartFilterButton), findsOneWidget);
      expect(find.text('嘉然'), findsOneWidget);
      await tester.tap(find.byTooltip('更多内容操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存频道'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存当前筛选'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '我的二创');
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('更多内容操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存频道'));
      await tester.pumpAndSettle();
      expect(find.text('我的二创'), findsOneWidget);
      await tester.tap(find.byTooltip('关闭频道'));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(1200, 900);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(FanartCard).first).width,
        lessThan(280),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('slow upward scrolling reveals the hidden page bar', (
    tester,
  ) async {
    late BuildContext bodyContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: const AppPageBar(title: Text('内容')),
          body: Builder(
            builder: (context) {
              bodyContext = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    var pixels = 200.0;
    void scroll(double delta) {
      pixels += delta;
      final metrics = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 1000,
        pixels: pixels,
        viewportDimension: 600,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1,
      );
      ScrollStartNotification(
        metrics: metrics,
        context: bodyContext,
      ).dispatch(bodyContext);
      ScrollUpdateNotification(
        metrics: metrics,
        context: bodyContext,
        scrollDelta: delta,
      ).dispatch(bodyContext);
      ScrollEndNotification(
        metrics: metrics,
        context: bodyContext,
      ).dispatch(bodyContext);
    }

    final slide = find.descendant(
      of: find.byType(AppPageBar),
      matching: find.byType(AnimatedSlide),
    );
    scroll(8);
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedSlide>(slide).offset.dy, lessThan(0));
    for (var i = 0; i < 4; i++) {
      scroll(-2);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedSlide>(slide).offset, Offset.zero);
  });

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
        // The feed's own search row leads it right under the bar, then the
        // two quick-filter strips (members, categories).
        final search = tester.getRect(find.byType(ContentSearchControl));
        expect(
          search.top - toolbar.bottom,
          lessThan(12),
          reason: 'no band between them',
        );
        final quick = tester.getRect(find.byType(FanartQuickFilters));
        expect(quick.top - search.bottom, lessThanOrEqualTo(12));
        // Two 48 dp touch strips (30 dp pills) plus their gap, nothing more.
        expect(quick.height, lessThanOrEqualTo(2 * 48 + 6));
        final filters = tester.getRect(find.byType(FanartFilterBar));
        final firstCard = tester.getTopLeft(find.byType(FanartCard).first).dy;
        expect(
          firstCard - filters.bottom,
          lessThan(72),
          reason: 'only grid padding separates the filters from the first row',
        );
        // Search is an inline field in the feed at every width.
        expect(find.byType(TextField), findsOneWidget);
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
      expect(find.widgetWithText(AppButton, '重试'), findsOneWidget);
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
    await tester.tap(find.widgetWithText(AppButton, '重试'));
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

    await tester.tap(find.text('嘉然'));
    await tester.pumpAndSettle();

    expect(repository.queries.last.characters, {FanartCharacter.diana});
    // A filter change starts a new run, so it must not carry an old cursor.
    expect(repository.cursors.last, isNull);
  });

  testWidgets('submitting a search applies the keyword', (tester) async {
    final repository = _StubRepository();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '嘉然');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(repository.queries.last.keyword, '嘉然');
  });

  testWidgets('UX3: the random draw opens a post directly', (tester) async {
    final repository = _StubRepository();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多内容操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('随机二创'));
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
      await tester.tap(find.text('嘉然'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '生日');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('更多内容操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('随机二创'));
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

  testWidgets('the narrowest phone keeps two readable artwork columns', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_StubRepository()));
    await tester.pumpAndSettle();

    // A fixed-extent grid: two columns of tiles no narrower than 136.
    expect(_gridColumns(tester), 2);
    expect(
      tester.getSize(find.byType(FanartCard).first).width,
      greaterThanOrEqualTo(136),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('double text size drops to one readable column', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(_app(_StubRepository()));
    await tester.pumpAndSettle();

    expect(_gridColumns(tester), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide windows use more columns than a phone', (tester) async {
    tester.view
      ..physicalSize = const Size(1600, 1200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_StubRepository()));
    await tester.pumpAndSettle();

    expect(_gridColumns(tester), greaterThan(2));
  });

  testWidgets(
    'only two channels stay mounted; a returning channel keeps pages and offset',
    (tester) async {
      final repository = _StubRepository();
      final channel = ValueNotifier('fanart');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...offlineLibrary(),
            fanartRepositoryProvider.overrideWithValue(repository),
            communityVideoRepositoryProvider.overrideWithValue(
              _EmptyCommunityRepository(),
            ),
            dynamicRepositoryProvider.overrideWithValue(_NoDynamics()),
            novelRepositoryProvider.overrideWithValue(_NoNovels()),
          ],
          child: MaterialApp(
            home: ValueListenableBuilder(
              valueListenable: channel,
              builder: (_, slug, _) => ContentPage(channel: slug),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final grid = find
          .descendant(
            of: find.byKey(const PageStorageKey('fanart-feed')),
            matching: find.byType(Scrollable),
          )
          .first;
      tester.state<ScrollableState>(grid).position.jumpTo(700);
      await tester.pumpAndSettle();
      final offset = tester.state<ScrollableState>(grid).position.pixels;
      expect(offset, greaterThan(300));
      final requests = repository.requests;
      for (final slug in ['dynamics', 'novels', 'videos']) {
        channel.value = slug;
        await tester.pumpAndSettle();
      }
      // Fanart is two switches old: unmounted, cards and images released.
      // Offstage still counts as mounted, so look past Offstage.
      expect(
        find.byKey(const PageStorageKey('fanart-feed'), skipOffstage: false),
        findsNothing,
      );
      expect(find.byType(DynamicFeedView, skipOffstage: false), findsNothing);
      expect(find.byType(NovelFeedView, skipOffstage: false), findsOneWidget);
      channel.value = 'fanart';
      await tester.pumpAndSettle();
      // Rebuilt from its controller and PageStorage: no refetch, same place.
      expect(repository.requests, requests);
      expect(tester.state<ScrollableState>(grid).position.pixels, offset);
      expect(tester.takeException(), isNull);
    },
  );
}

int _gridColumns(WidgetTester tester) {
  final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
  return (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
      .crossAxisCount;
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

class _NoDynamics implements DynamicRepository {
  @override
  Future<DynamicPage> search({
    DynamicQuery query = const DynamicQuery(),
    String? cursor,
    RequestCancellation? cancellation,
  }) async => const DynamicPage(items: []);

  @override
  Future<List<DynamicPost>> onThisDay({
    String? monthDay,
    OnThisDaySort sort = OnThisDaySort.hot,
    int limit = 8,
  }) async => const [];

  @override
  Future<List<DynamicMember>> members() async => const [];
}

class _NoNovels implements NovelRepository {
  @override
  Future<NovelPage> search({
    NovelQuery query = const NovelQuery(),
    int offset = 0,
    RequestCancellation? cancellation,
  }) async => NovelPage(items: const [], total: 0, offset: offset, limit: 20);

  @override
  Future<NovelDetail> detail(
    String sourceTid, {
    RequestCancellation? cancellation,
  }) => throw UnimplementedError();

  @override
  Future<NovelFacets> facets() async =>
      const NovelFacets(total: 0, byRating: {});
}
