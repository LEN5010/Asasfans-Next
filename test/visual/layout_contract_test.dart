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
      final top = texts(tester).map((rect) => rect.top).reduce(
        (a, b) => a < b ? a : b,
      );
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

  testVisual('a focused search stays above the keyboard', (tester) async {
    final keyboard = bars.withKeyboard(300);
    await pumpVisualApp(tester, view: keyboard, location: '/content/fanart');
    await tester.tap(find.byType(TextField).first);
    await settleVisual(tester);
    final field = tester.getRect(find.byType(TextField).first);
    expect(field.bottom, lessThanOrEqualTo(keyboard.size.height - 300));
    expect(tester.takeException(), isNull);
    await shoot(tester, 'fanart-search-keyboard', keyboard);
  });
}
