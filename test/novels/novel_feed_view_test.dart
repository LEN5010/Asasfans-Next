import 'package:asasfans_next/features/novels/application/novel_providers.dart';
import 'package:asasfans_next/features/novels/domain/novel_repository.dart';
import 'package:asasfans_next/features/novels/presentation/novel_feed_view.dart';
import 'package:flutter/material.dart';
import 'package:asasfans_next/shared/widgets/app_controls.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

NovelSummary _summary(String tid, {NovelRating rating = NovelRating.sfw}) =>
    NovelSummary(
      id: 'w$tid',
      sourceTid: tid,
      title: '作品 $tid',
      authorName: '作者 $tid',
      rating: rating,
      characters: const [NovelCharacter.diana],
      charCount: 23456,
      excerpt: rating == NovelRating.sfw ? '摘要 $tid' : '',
      images: const [],
      createdAt: DateTime(2021, 5, 1),
    );

class _Repository implements NovelRepository {
  final queries = <NovelQuery>[];

  @override
  Future<NovelPage> search({
    NovelQuery query = const NovelQuery(),
    int offset = 0,
    RequestCancellation? cancellation,
  }) async {
    queries.add(query);
    return NovelPage(
      items: [
        _summary('1'),
        _summary('2', rating: NovelRating.nsfw),
      ],
      total: 2,
      offset: offset,
      limit: query.limit,
    );
  }

  @override
  Future<NovelDetail> detail(
    String sourceTid, {
    RequestCancellation? cancellation,
  }) async => sourceTid == '1'
      ? NovelDetail(
          summary: _summary('1'),
          contentVisible: true,
          blocks: const [
            NovelTextBlock.heading('第一章', 2),
            NovelTextBlock('正文第一段'),
            NovelDividerBlock(),
          ],
          warnings: const [],
          externalLinks: const [],
          primaryKind: NovelPrimaryKind.main,
          externalCharCount: 0,
        )
      : NovelDetail(
          summary: _summary('2', rating: NovelRating.nsfw),
          contentVisible: false,
          blocks: const [],
          warnings: const ['性相关'],
          externalLinks: [
            NovelExternalLink(
              url: Uri.parse('https://www.douban.com/group/topic/2/'),
              kind: NovelLinkKind.source,
              label: '豆瓣原帖',
            ),
          ],
          primaryKind: NovelPrimaryKind.main,
          externalCharCount: 0,
        );

  @override
  Future<NovelFacets> facets() async => const NovelFacets(
    total: 2,
    byRating: {NovelRating.sfw: 1, NovelRating.nsfw: 1},
  );
}

void main() {
  Future<_Repository> pump(WidgetTester tester, double width) async {
    tester.view
      ..physicalSize = Size(width, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _Repository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [novelRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: Scaffold(body: NovelFeedView())),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  for (final width in [320.0, 1200.0]) {
    testWidgets('UI UX: novel all-rating directory at width $width', (
      tester,
    ) async {
      final repository = await pump(tester, width);
      expect(repository.queries.single.rating, NovelRatingFilter.all);
      expect(find.text('作品 1'), findsOneWidget);
      expect(find.text('摘要 1'), findsOneWidget);
      expect(find.textContaining('2.3 万字'), findsNWidgets(2));
      expect(find.text('正文已遮挡'), findsOneWidget);
      expect(find.textContaining('2 部'), findsOneWidget);
      expect(find.text('摘要 2'), findsNothing);
      final first = tester.getTopLeft(find.text('作品 1'));
      final second = tester.getTopLeft(find.text('作品 2'));
      // Cards: one column on a phone, side by side once there is room.
      if (width > 760) {
        expect(second.dx, greaterThan(first.dx));
      } else {
        expect(second.dy, greaterThan(first.dy));
        expect(second.dx, first.dx);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [400.0, 800.0]) {
    testWidgets('novel filters cancel or apply one draft at width $width', (
      tester,
    ) async {
      final repository = await pump(tester, width);
      final rating = find.byType(AppSegments<NovelRatingFilter>);
      final r18 = find.descendant(of: rating, matching: find.text('R18'));
      expect(rating, findsNothing);

      await tester.tap(find.byTooltip('筛选与排序'));
      await tester.pumpAndSettle();
      expect(find.text('筛选小说'), width < 600 ? findsOneWidget : findsNothing);
      await tester.tap(find.widgetWithText(AppButton, '嘉然'));
      await tester.tap(r18);
      await tester.pumpAndSettle();
      expect(repository.queries, [const NovelQuery()]);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(rating, findsNothing);

      await tester.tap(find.byTooltip('筛选与排序'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<AppSegments<NovelRatingFilter>>(rating).selected,
        NovelRatingFilter.all,
      );
      expect(
        tester.widget<AppButton>(find.widgetWithText(AppButton, '嘉然')).selected,
        isFalse,
      );
      await tester.tap(find.widgetWithText(AppButton, '嘉然'));
      await tester.tap(r18);
      await tester.pumpAndSettle();
      expect(repository.queries.length, 1);
      await tester.tap(find.text('应用筛选'));
      await tester.pumpAndSettle();
      expect(repository.queries.length, 2);
      expect(repository.queries.last.rating, NovelRatingFilter.nsfw);
      expect(repository.queries.last.characters, {NovelCharacter.diana});
      expect(rating, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'inline novel draft follows search and clear, resize never applies',
    (tester) async {
      final repository = await pump(tester, 800);
      final rating = find.byType(AppSegments<NovelRatingFilter>);
      final r18 = find.descendant(of: rating, matching: find.text('R18'));
      await tester.tap(find.byTooltip('筛选与排序'));
      await tester.pumpAndSettle();
      await tester.tap(r18);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '新的搜索');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(repository.queries.last, const NovelQuery(keyword: '新的搜索'));
      expect(
        tester.widget<AppSegments<NovelRatingFilter>>(rating).selected,
        NovelRatingFilter.all,
      );

      await tester.tap(r18);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('清除小说筛选'));
      await tester.pumpAndSettle();
      expect(repository.queries.last, const NovelQuery());
      expect(
        tester.widget<AppSegments<NovelRatingFilter>>(rating).selected,
        NovelRatingFilter.all,
      );

      await tester.tap(r18);
      await tester.pumpAndSettle();
      final committed = repository.queries.length;
      tester.view.physicalSize = const Size(400, 900);
      await tester.pumpAndSettle();
      expect(rating, findsNothing);
      tester.view.physicalSize = const Size(800, 900);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(
        tester.widget<AppSegments<NovelRatingFilter>>(rating).selected,
        NovelRatingFilter.all,
      );
      for (final text in ['角色', '分级', '搜索范围', '排序', '应用筛选']) {
        await tester.ensureVisible(find.text(text));
      }
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(repository.queries.length, committed);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the reader lays out text blocks', (tester) async {
    await pump(tester, 1200);
    await tester.tap(find.text('作品 1'));
    await tester.pumpAndSettle();
    expect(find.text('第一章'), findsOneWidget);
    expect(find.textContaining('正文第一段'), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an R18 work shows warnings and links, never text', (
    tester,
  ) async {
    await pump(tester, 400);
    await tester.tap(find.text('作品 2'));
    await tester.pumpAndSettle();
    expect(find.textContaining('性相关'), findsOneWidget);
    expect(find.textContaining('这是 R18 作品'), findsOneWidget);
    expect(find.text('豆瓣原帖'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
