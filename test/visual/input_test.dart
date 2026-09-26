import 'package:asasfans_next/features/content/presentation/fanart_card.dart';
import 'package:asasfans_next/features/content/presentation/fanart_detail_page.dart';
import 'package:asasfans_next/shared/widgets/media_card_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_harness.dart';

/// U21: the new surfaces by keyboard and by touch geometry.
void main() {
  setUpAll(Visual.setUp);

  testVisual('a work tile takes focus, shows it, and opens with Enter', (
    tester,
  ) async {
    await pumpVisualApp(
      tester,
      view: VisualView.wide,
      location: '/content/fanart',
    );
    // Move focus through the page until it lands in a work tile.
    Element? focusedTile;
    for (var i = 0; i < 40 && focusedTile == null; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focus = FocusManager.instance.primaryFocus?.context;
      focus?.visitAncestorElements((element) {
        if (element.widget is FanartCard) {
          focusedTile = element;
          return false;
        }
        return true;
      });
    }
    expect(focusedTile, isNotNull, reason: 'Tab reaches the works');
    await settleVisual(tester, rounds: 2);
    await shoot(tester, 'input-focus-tile', VisualView.wide);
    final item = (focusedTile!.widget as FanartCard).item;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleVisual(tester);
    if (item.contentType.name == 'video') {
      // Video works hand off to B站 instead of opening a detail.
      expect(find.byType(FanartDetailPage), findsNothing);
    } else {
      expect(find.byType(FanartDetailPage), findsOneWidget);
      // Esc/back returns to where the focus came from.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settleVisual(tester);
    }
  });

  testVisual('touch targets on a work tile are 48 and do not overlap', (
    tester,
  ) async {
    await pumpVisualApp(
      tester,
      view: VisualView.phone,
      location: '/content/fanart',
    );
    final tile = find.byType(FanartCard).first;
    final more = find.descendant(
      of: tile,
      matching: find.byType(MediaMoreButton),
    );
    final button = tester.getRect(
      find.descendant(of: more, matching: find.byType(TextButton)),
    );
    expect(button.width, greaterThanOrEqualTo(48));
    expect(button.height, greaterThanOrEqualTo(48));
    // The more button stays inside its tile, so it never takes a neighbour's
    // tap, and a tap on it does not open the work.
    expect(tester.getRect(tile).contains(button.center), isTrue);
    await tester.tap(more);
    await settleVisual(tester);
    expect(find.byType(FanartDetailPage), findsNothing);
    expect(find.text('稍后看'), findsWidgets);
  });
}
