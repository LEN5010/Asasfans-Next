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

  group('long conditions stay inside the line', () {
    final longChinese = '“${'秋天的第一杯奶茶和枫叶围巾' * 3}”'; // 40+ characters
    final unbroken = '“${'x' * 120}”';
    for (final width in [320.0, 390.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$width wide at ${scale}x', (tester) async {
          tester.view
            ..physicalSize = Size(width, 700)
            ..devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final removed = <String>[];
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 700),
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: QuerySummary(
                    onClear: () {},
                    status: '12 条',
                    applied: [
                      for (final label in [longChinese, unbroken])
                        (label: label, remove: () => removed.add(label)),
                    ],
                  ),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          // Every part of the line is inside the screen and still usable;
          // the whole value stays in the tooltip.
          for (final label in [longChinese, unbroken]) {
            final chip = find.byTooltip('移除“$label”');
            expect(chip, findsOneWidget);
            final rect = tester.getRect(chip);
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(width));
            await tester.tap(chip);
          }
          expect(removed, [longChinese, unbroken]);
          expect(tester.getRect(find.text('清空')).right, lessThanOrEqualTo(width));
        });
      }
    }
  });

  testWidgets('many conditions fold behind a count until asked', (
    tester,
  ) async {
    final labels = ['最热', '一周内', '手书·动画', '图片', 'Bilibili', '最早'];
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 320,
          child: QuerySummary(
            onClear: () {},
            applied: [for (final l in labels) (label: l, remove: () {})],
          ),
        ),
      ),
    );
    expect(find.byTooltip('移除“最热”'), findsOneWidget);
    expect(find.byTooltip('移除“一周内”'), findsOneWidget);
    expect(find.byTooltip('移除“最早”'), findsNothing);
    await tester.tap(find.text('另 4 项'));
    await tester.pumpAndSettle();
    for (final label in labels) {
      expect(find.byTooltip('移除“$label”'), findsOneWidget);
    }
    await tester.tap(find.text('收起'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('移除“最早”'), findsNothing);
  });

  testWidgets('clearing fanart conditions says it keeps the members, and '
      'equals removing each one', (tester) async {
    const query = FanartQuery(
      keyword: '秋天',
      characters: {FanartCharacter.diana},
      category: FanartCategory.handwriting,
      contentType: FanartContentType.image,
      sort: FanartSort.oldest,
    );
    FanartQuery? cleared;
    await tester.pumpWidget(
      host(
        FanartFilterBar(query: query, onChanged: (value) => cleared = value),
      ),
    );
    expect(find.text('清除条件'), findsOneWidget);
    await tester.tap(find.byTooltip('清除条件，成员不变'));
    expect(cleared!.characters, {FanartCharacter.diana});

    // Removing the conditions one at a time lands on the same query.
    var current = query;
    while (true) {
      await tester.pumpWidget(
        host(
          FanartFilterBar(
            query: current,
            onChanged: (value) => current = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final chips = find.byWidgetPredicate(
        (widget) =>
            widget is Tooltip && (widget.message ?? '').startsWith('移除'),
      );
      if (chips.evaluate().isEmpty) {
        final more = find.textContaining(RegExp(r'^另 \d+ 项$'));
        if (more.evaluate().isEmpty) break;
        await tester.tap(more);
        await tester.pumpAndSettle();
        continue;
      }
      await tester.tap(chips.first);
    }
    expect(current, cleared);
  });
}
