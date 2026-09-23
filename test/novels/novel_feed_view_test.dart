import 'package:asasfans_next/features/novels/application/novel_providers.dart';
import 'package:asasfans_next/features/novels/domain/novel_repository.dart';
import 'package:asasfans_next/features/novels/presentation/novel_feed_view.dart';
import 'package:flutter/material.dart';
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
    testWidgets('lists works with filters at width $width', (tester) async {
      final repository = await pump(tester, width);
      expect(repository.queries.single.rating, NovelRatingFilter.sfw);
      expect(find.text('作品 1'), findsOneWidget);
      expect(find.text('摘要 1'), findsOneWidget);
      expect(find.text('2.3 万字'), findsNWidgets(2));
      expect(find.textContaining('应用内不显示正文'), findsOneWidget);
      expect(find.text('全年龄 1'), findsOneWidget);
      expect(find.textContaining('共 2 部'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a rating chip reloads with the new filter', (tester) async {
    final repository = await pump(tester, 400);
    await tester.tap(find.text('R18 1'));
    await tester.pumpAndSettle();
    expect(repository.queries.last.rating, NovelRatingFilter.nsfw);
  });

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
