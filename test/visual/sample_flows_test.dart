import 'package:asasfans_next/features/content/presentation/content_page.dart';
import 'package:asasfans_next/features/library/application/library_providers.dart';
import 'package:asasfans_next/features/content/presentation/fanart_card.dart';
import 'package:asasfans_next/features/content/presentation/fanart_detail_page.dart';
import 'package:asasfans_next/shared/widgets/app_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_harness.dart';

/// U06: the three interactions the sample must carry, driven through the
/// real app and captured step by step (filter, detail and back, save).
void main() {
  setUpAll(Visual.setUp);
  const view = VisualView.phone;

  ScrollableState feed(WidgetTester tester) => tester
      .stateList<ScrollableState>(
        find.descendant(
          of: find.byType(ContentPage),
          matching: find.byType(Scrollable),
        ),
      )
      .firstWhere((state) => state.axisDirection == AxisDirection.down);

  testVisual('filter: draft, apply, summary, remove', (tester) async {
    await pumpVisualApp(tester, view: view, location: '/content/fanart');
    await tester.tap(find.byTooltip('筛选'));
    await settleVisual(tester);
    await tester.tap(find.widgetWithText(AppChoice, '手书·动画').last);
    await settleVisual(tester, rounds: 2);
    await shoot(tester, 'flow-filter-1-draft', view);
    await tester.tap(find.widgetWithText(AppButton, '应用筛选'));
    await settleVisual(tester);
    // The applied condition is named in the summary and removable alone.
    expect(find.byTooltip('移除“手书·动画”'), findsOneWidget);
    await shoot(tester, 'flow-filter-2-applied', view);

    // A draft closed without applying changes nothing.
    await tester.tap(find.byTooltip('筛选'));
    await settleVisual(tester);
    await tester.tap(find.widgetWithText(AppChoice, '物料').last);
    await tester.tap(find.byTooltip('关闭筛选'));
    await settleVisual(tester);
    expect(find.byTooltip('移除“物料”'), findsNothing);
    expect(find.byTooltip('移除“手书·动画”'), findsOneWidget);

    await tester.tap(find.byTooltip('移除“手书·动画”'));
    await settleVisual(tester);
    expect(find.byTooltip('移除“手书·动画”'), findsNothing);
    expect(find.byTooltip('重置筛选'), findsNothing);
  });

  testVisual('detail: open a work and come back to the same place', (
    tester,
  ) async {
    await pumpVisualApp(tester, view: view, location: '/content/fanart');
    await tester.drag(find.byType(FanartCard).first, const Offset(0, -420));
    await settleVisual(tester);
    final before = feed(tester).position.pixels;
    expect(before, greaterThan(300));
    // An image work fully on screen, below the page bar.
    final target = find.byType(FanartCard).evaluate().firstWhere((element) {
      final card = element.widget as FanartCard;
      final rect = tester.getRect(find.byWidget(card));
      return card.item.images.isNotEmpty &&
          card.item.sourceUrl != null &&
          card.item.contentType.name == 'image' &&
          rect.top > 120 &&
          rect.bottom < 760;
    });
    await tester.tap(find.byWidget(target.widget));
    await settleVisual(tester);
    expect(find.byType(FanartDetailPage), findsOneWidget);
    await shoot(tester, 'flow-detail-1-open', view);
    await tester.tap(find.byTooltip('返回'));
    await settleVisual(tester);
    expect(find.byType(FanartDetailPage), findsNothing);
    expect(feed(tester).position.pixels, before);
    await shoot(tester, 'flow-detail-2-back', view);

    // The visit is in 我的 → 最近浏览.
    visualRouter(tester).go('/mine');
    await settleVisual(tester);
    expect(find.text('最近浏览'), findsOneWidget);
    await shoot(tester, 'flow-detail-3-mine-recent', view);
  });

  testVisual('save: the sheet shows the result where it happened', (
    tester,
  ) async {
    await pumpVisualApp(tester, view: view, location: '/content/fanart');
    await tester.longPress(find.byType(FanartCard).first);
    await settleVisual(tester);
    final later = find.byWidgetPredicate(
      (widget) => widget is AppSwitch && widget.label == '稍后看',
    );
    expect(tester.widget<AppSwitch>(later).value, isFalse);
    await tester.tap(later);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await settleVisual(tester);
    expect(tester.widget<AppSwitch>(later).value, isTrue);
    // And it is stored, not only drawn.
    final item = tester.widget<FanartCard>(find.byType(FanartCard).first).item;
    final state = await tester.runAsync(
      () => visualContainer(
        tester,
      ).read(libraryRepositoryProvider).itemState(item.identity),
    );
    expect(state!.later, isTrue);
    await shoot(tester, 'flow-save-1-later-on', view);
  });

  testVisual('settings: preferences on their own page', (tester) async {
    await pumpVisualApp(tester, view: view, location: '/mine/settings');
    expect(find.text('主题'), findsOneWidget);
    await shoot(tester, 'settings', view);
  });
}
