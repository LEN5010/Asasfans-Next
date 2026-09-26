import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/features/content/presentation/fanart_filter_bar.dart';
import 'package:asasfans_next/shared/widgets/query_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('defaults take no space; a status alone still shows', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(QuerySummary(applied: const [], onClear: () {})),
    );
    expect(find.byType(Wrap), findsNothing);
    expect(find.text('清空'), findsNothing);

    await tester.pumpWidget(
      host(QuerySummary(applied: const [], onClear: () {}, status: '4 部')),
    );
    expect(find.text('4 部'), findsOneWidget);
    // Nothing to clear while nothing is applied.
    expect(find.text('清空'), findsNothing);
  });

  testWidgets('each condition removes only itself; 清空 removes all', (
    tester,
  ) async {
    final removed = <String>[];
    var cleared = 0;
    await tester.pumpWidget(
      host(
        QuerySummary(
          clearTooltip: '清除筛选',
          onClear: () => cleared++,
          applied: [
            (label: '最热', remove: () => removed.add('最热')),
            (label: '一周内', remove: () => removed.add('一周内')),
          ],
        ),
      ),
    );
    await tester.tap(find.byTooltip('移除“一周内”'));
    expect(removed, ['一周内']);
    await tester.tap(find.byTooltip('清除筛选'));
    expect(cleared, 1);
  });

  testWidgets('fanart names only non-default panel conditions', (tester) async {
    FanartQuery? next;
    const query = FanartQuery(
      keyword: '秋天',
      characters: {FanartCharacter.diana},
      category: FanartCategory.handwriting,
      sort: FanartSort.oldest,
    );
    await tester.pumpWidget(
      host(FanartFilterBar(query: query, onChanged: (value) => next = value)),
    );
    // Members have their own strip, so they are not repeated here.
    expect(find.byTooltip('移除“嘉然”'), findsNothing);
    expect(find.byTooltip('移除““秋天””'), findsOneWidget);
    expect(find.byTooltip('移除“最早”'), findsOneWidget);
    await tester.tap(find.byTooltip('移除“手书·动画”'));
    expect(next!.category, FanartCategory.all);
    // The rest of the query is untouched by one removal.
    expect(next!.keyword, '秋天');
    expect(next!.sort, FanartSort.oldest);
    expect(next!.characters, {FanartCharacter.diana});
  });
}
