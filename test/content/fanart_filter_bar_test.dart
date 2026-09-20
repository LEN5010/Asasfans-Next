import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/features/content/presentation/fanart_filter_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FanartQuery query;

  Future<void> pump(WidgetTester tester, FanartQuery initial) {
    query = initial;
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => FanartFilterBar(
              query: query,
              onChanged: (next) => setState(() => query = next),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> choose(
    WidgetTester tester,
    String trigger,
    String option,
  ) async {
    await tester.tap(find.text(trigger));
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  testWidgets('selecting characters accumulates and deselecting removes', (
    tester,
  ) async {
    await pump(tester, const FanartQuery());

    await tester.tap(find.widgetWithText(FilterChip, '嘉然'));
    await tester.pumpAndSettle();
    expect(query.characters, {FanartCharacter.diana});

    await tester.tap(find.widgetWithText(FilterChip, '贝拉'));
    await tester.pumpAndSettle();
    expect(query.characters, {FanartCharacter.diana, FanartCharacter.bella});

    await tester.tap(find.widgetWithText(FilterChip, '嘉然'));
    await tester.pumpAndSettle();
    expect(query.characters, {FanartCharacter.bella});
  });

  testWidgets('choosing a metric sort narrows the query to videos', (
    tester,
  ) async {
    await pump(tester, const FanartQuery());

    await choose(tester, '最新', '播放最多');

    expect(query.sort, FanartSort.views);
    // Otherwise the server rejects the request with 400.
    expect(query.contentType, FanartContentType.video);
    expect(query.isServerAcceptable, isTrue);
  });

  testWidgets('a metric sort drops a douban-only source instead of failing', (
    tester,
  ) async {
    await pump(tester, const FanartQuery(source: FanartSource.douban));

    await choose(tester, '最新', '收藏最多');

    expect(query.sort, FanartSort.favorites);
    expect(query.source, isNot(FanartSource.douban));
    expect(query.isServerAcceptable, isTrue);
  });

  testWidgets('leaving video content clears a metric sort', (tester) async {
    await pump(
      tester,
      const FanartQuery(
        sort: FanartSort.views,
        contentType: FanartContentType.video,
      ),
    );

    await choose(tester, '视频', '图片');

    expect(query.contentType, FanartContentType.image);
    expect(query.sort, FanartSort.newest);
    expect(query.isServerAcceptable, isTrue);
  });

  testWidgets('a non-metric sort leaves the content type alone', (
    tester,
  ) async {
    await pump(tester, const FanartQuery(contentType: FanartContentType.image));

    await choose(tester, '最新', '最早');

    expect(query.sort, FanartSort.oldest);
    expect(query.contentType, FanartContentType.image);
  });

  testWidgets('category selection uses the exact server wire value', (
    tester,
  ) async {
    await pump(tester, const FanartQuery());

    await choose(tester, '全部分类', '剪辑·AMV');

    expect(query.category, FanartCategory.amv);
    expect(query.category.wire, '剪辑·AMV');
  });

  testWidgets('every reachable combination stays server-acceptable', (
    tester,
  ) async {
    await pump(tester, const FanartQuery());
    for (final label in ['播放最多', '收藏最多', '最早', '最新']) {
      await choose(tester, _sortLabel(query.sort), label);
      expect(query.isServerAcceptable, isTrue, reason: label);
    }
  });
}

String _sortLabel(FanartSort sort) => switch (sort) {
  FanartSort.newest => '最新',
  FanartSort.oldest => '最早',
  FanartSort.views => '播放最多',
  FanartSort.favorites => '收藏最多',
};
