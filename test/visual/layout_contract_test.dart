import 'package:asasfans_next/shared/widgets/glass/app_glass_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_harness.dart';

/// R08: a few core pages held to geometry, in ordinary test runs. These
/// fail when a layout regresses (the ledger records one deliberate break);
/// a written PNG alone would not.
void main() {
  setUpAll(Visual.setUp);
  final bars = VisualView.phone.withSystemBars;

  ScrollableState mainList(WidgetTester tester) => tester
      .stateList<ScrollableState>(find.byType(Scrollable))
      .where((state) => state.axisDirection == AxisDirection.down)
      .reduce(
        (a, b) =>
            tester.getSize(find.byWidget(a.widget)).height >=
                tester.getSize(find.byWidget(b.widget)).height
            ? a
            : b,
      );

  /// Every on-screen line of text inside the page, as rects.
  List<Rect> texts(WidgetTester tester) => [
    for (final element in find.byType(RichText).evaluate())
      if (find
          .ancestor(
            of: find.byElementPredicate((e) => e == element),
            matching: find.byType(AppGlassNavigation),
          )
          .evaluate()
          .isEmpty)
        tester.getRect(find.byElementPredicate((e) => e == element)),
  ];

  for (final (name, location) in [
    ('today', '/today'),
    ('fanart', '/content/fanart'),
    ('mine', '/mine'),
  ]) {
    testVisual('$name: the head clears the status bar, and the end clears '
        'the floating bar', (tester) async {
      await pumpVisualApp(tester, view: bars, location: location);
      final top = texts(
        tester,
      ).map((rect) => rect.top).reduce((a, b) => a < b ? a : b);
      expect(top, greaterThanOrEqualTo(bars.safeArea.top));

      // To the very end, as far as the list goes (loading more as it does).
      for (var i = 0; i < 6; i++) {
        final list = mainList(tester);
        list.position.jumpTo(list.position.maxScrollExtent);
        await settleVisual(tester, rounds: 3);
      }
      final bar = tester.getRect(find.byType(AppGlassNavigation));
      final lowest = texts(tester)
          .where((rect) => rect.top < bars.size.height)
          .map((rect) => rect.bottom)
          .reduce((a, b) => a > b ? a : b);
      expect(lowest, lessThanOrEqualTo(bar.top));
      await shoot(tester, '$name-end', bars);
    });
  }

  testVisual('a search in a bottom panel stays above the keyboard', (
    tester,
  ) async {
    // A panel rises from the bottom edge, where a keyboard opens: its field
    // is the one that could end up underneath. (A page's own search sits at
    // the top and is never at risk.)
    final keyboard = bars.withKeyboard(300);
    await pumpVisualApp(tester, view: bars, location: '/mine');
    final entry = find.text('工具与相关站点');
    await tester.scrollUntilVisible(
      entry,
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.runAsync(
      () => Scrollable.ensureVisible(tester.element(entry), alignment: .5),
    );
    await settleVisual(tester);
    await tester.tap(entry);
    await settleVisual(tester);
    final search = find.widgetWithText(TextField, '搜索工具');
    await tester.tap(search);
    // The keyboard rises after the tap, as on a phone.
    tester.view.viewInsets = FakeViewPadding(
      bottom: keyboard.keyboard * keyboard.pixelRatio,
    );
    await settleVisual(tester);
    expect(
      tester.getRect(search).bottom,
      lessThanOrEqualTo(keyboard.size.height - keyboard.keyboard),
    );
    expect(tester.takeException(), isNull);
    await shoot(tester, 'tools-search-keyboard', keyboard);
  });
}
