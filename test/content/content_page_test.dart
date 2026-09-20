import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/content/application/content_providers.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/features/content/presentation/content_page.dart';
import 'package:asasfans_next/features/content/presentation/fanart_detail_page.dart';
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
  _StubRepository({this.pages = 3, this.pageSize = 8, this.failFirst = false});

  final int pages;
  final int pageSize;
  final bool failFirst;
  int requests = 0;
  int randomDraws = 0;
  final List<FanartQuery> queries = [];
  final List<String?> cursors = [];

  @override
  Future<FanartItem?> random({
    FanartQuery query = const FanartQuery(),
    RequestCancellation? cancellation,
  }) async {
    randomDraws++;
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
  overrides: [fanartRepositoryProvider.overrideWithValue(repository)],
  child: const MaterialApp(home: ContentPage()),
);

void main() {
  testWidgets(
    'the fanart channel renders real items instead of a placeholder',
    (tester) async {
      await tester.pumpWidget(_app(_StubRepository()));
      await tester.pumpAndSettle();

      expect(find.text('即将开放'), findsNothing);
      expect(find.text('作品 p0i0'), findsOneWidget);
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
      scrollable: find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      ),
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

  testWidgets('channels without a wired source stay explicitly pending', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fanartRepositoryProvider.overrideWithValue(_StubRepository()),
        ],
        child: const MaterialApp(home: ContentPage(channel: 'clips')),
      ),
    );
    await tester.pumpAndSettle();

    // Live clips are a separate source and must not borrow the fanart dataset.
    expect(find.text('即将开放'), findsOneWidget);
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

  testWidgets('the random action is absent on channels it cannot serve', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fanartRepositoryProvider.overrideWithValue(_StubRepository()),
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
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
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
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, greaterThan(2));
  });
}
