import 'package:asasfans_next/shared/widgets/app_controls.dart';
import 'package:asasfans_next/features/content/application/fanart_filter_rules.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/features/content/presentation/fanart_filter_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FanartQuery query;
  var changes = 0;
  Future<void> pump(WidgetTester tester, FanartQuery initial) {
    query = initial;
    changes = 0;
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (_, setState) {
              void apply(FanartQuery value) => setState(() {
                query = value;
                changes++;
              });
              return Column(
                children: [
                  FanartFilterButton(query: query, onChanged: apply),
                  FanartFilterBar(query: query, onChanged: apply),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byTooltip('筛选'));
    await tester.pumpAndSettle();
  }

  Future<void> pick(WidgetTester tester, String option) async {
    // Test against the unqualified finder: `.last` on an empty match throws
    // StateError from evaluate(), so the emptiness guard never ran and an
    // option that merely had not been built yet looked like a missing one.
    final matches = find.widgetWithText(AppChoice, option);
    if (matches.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        matches,
        160,
        scrollable: find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Scrollable),
        ),
      );
    }
    final finder = matches.last;
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> apply(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(AppButton, '应用筛选'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'UX3: member filters are draft-only and accumulate in the panel',
    (tester) async {
      await pump(tester, const FanartQuery());
      expect(find.text('嘉然'), findsNothing);
      await open(tester);
      await pick(tester, '嘉然');
      await pick(tester, '贝拉');
      expect(query.characters, isEmpty);
      await apply(tester);
      expect(query.characters, {FanartCharacter.diana, FanartCharacter.bella});
      expect(changes, 1);
      await open(tester);
      await pick(tester, '嘉然');
      await tester.tap(find.byTooltip('关闭筛选'));
      await tester.pumpAndSettle();
      expect(query.characters, {FanartCharacter.diana, FanartCharacter.bella});
      expect(changes, 1);
    },
  );

  testWidgets('several draft changes issue exactly one application', (
    tester,
  ) async {
    await pump(tester, const FanartQuery());
    await open(tester);
    await pick(tester, '视频');
    await pick(tester, 'Bilibili');
    await pick(tester, '剪辑·AMV');
    await pick(tester, '播放最多');
    expect(changes, 0);
    await apply(tester);
    expect(changes, 1);
    expect(query.contentType, FanartContentType.video);
    expect(query.category, FanartCategory.amv);
    expect(query.source, FanartSource.bilibili);
    expect(query.sort, FanartSort.views);
    expect(query.isServerAcceptable, isTrue);
  });

  testWidgets('dismissal discards draft edits', (tester) async {
    await pump(tester, const FanartQuery());
    await open(tester);
    await pick(tester, '图片');
    await tester.tap(find.byTooltip('关闭筛选'));
    await tester.pumpAndSettle();
    expect(changes, 0);
    expect(query, const FanartQuery());
  });

  testWidgets('a metric sort selects videos and leaves a douban-only source', (
    tester,
  ) async {
    await pump(tester, const FanartQuery(source: FanartSource.douban));
    await open(tester);
    await pick(tester, '收藏最多');
    await apply(tester);
    expect(query.contentType, FanartContentType.video);
    expect(query.source, FanartSource.bilibili);
    expect(query.isServerAcceptable, isTrue);
  });

  testWidgets('leaving video content clears the incompatible metric sort', (
    tester,
  ) async {
    await pump(
      tester,
      const FanartQuery(
        contentType: FanartContentType.video,
        sort: FanartSort.views,
      ),
    );
    await open(tester);
    await pick(tester, '图片');
    await apply(tester);
    expect(query.sort, FanartSort.newest);
    expect(query.contentType, FanartContentType.image);
  });

  testWidgets('source and reset options preserve the submitted keyword', (
    tester,
  ) async {
    await pump(
      tester,
      const FanartQuery(
        keyword: '生日',
        contentType: FanartContentType.video,
        sort: FanartSort.views,
      ),
    );
    await open(tester);
    await pick(tester, '豆瓣');
    await apply(tester);
    expect(query.sort, FanartSort.newest);
    expect(query.source, FanartSource.douban);
    await open(tester);
    await tester.tap(find.widgetWithText(TextButton, '重置'));
    await apply(tester);
    expect(query, const FanartQuery(keyword: '生日'));
  });

  test('all type/source/sort transitions remain API-acceptable', () {
    for (final type in FanartContentType.values) {
      for (final source in FanartSource.values) {
        for (final sort in FanartSort.values) {
          var query = FanartFilterRules.contentType(const FanartQuery(), type);
          query = FanartFilterRules.sort(query, sort);
          query = FanartFilterRules.source(query, source);
          expect(
            query.isServerAcceptable,
            isTrue,
            reason: '$type/$source/$sort',
          );
        }
      }
    }
  });
}
