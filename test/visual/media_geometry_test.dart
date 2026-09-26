import 'package:asasfans_next/features/content/application/content_providers.dart';
import 'package:asasfans_next/features/content/presentation/content_page.dart';
import 'package:asasfans_next/features/content/presentation/fanart_card.dart';
import 'package:asasfans_next/features/content/presentation/fanart_detail_page.dart';
import 'package:asasfans_next/features/content/presentation/fanart_image_viewer.dart';
import 'package:asasfans_next/shared/widgets/media_cover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_fixture.dart';
import 'visual_harness.dart';

/// R03/R08: what a tile or a detail actually shows of a work, checked in
/// rendered pixels against art with a coloured band on each edge (red left,
/// blue right, green top, yellow bottom). A crop that loses an edge fails
/// here; a written PNG alone would not.
void main() {
  setUpAll(Visual.setUp);
  const view = VisualView.phone;

  Future<void> pumpDiagnostic(WidgetTester tester, {VisualView v = view}) =>
      pumpVisualApp(
        tester,
        view: v,
        location: '/content/fanart',
        overrides: visualOverrides(
          extra: [
            fanartRepositoryProvider.overrideWithValue(
              FixtureFanart(items: diagnosticFanart),
            ),
          ],
        ),
      );

  Finder tileOf(String id) => find.byWidgetPredicate(
    (widget) => widget is FanartCard && widget.item.identity.value == id,
  );

  Future<void> reveal(WidgetTester tester, Finder target) async {
    final list = find
        .descendant(
          of: find.byType(ContentPage),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        )
        .first;
    await tester.scrollUntilVisible(target, 200, scrollable: list);
    await tester.runAsync(
      () => Scrollable.ensureVisible(tester.element(target), alignment: .3),
    );
    await settleVisual(tester);
  }

  Rect coverOf(WidgetTester tester, String id) => tester.getRect(
    find.descendant(of: tileOf(id), matching: find.byType(MediaCover)),
  );

  /// Which of the four edge bands show inside [rect], sampled just inside
  /// each edge at its middle.
  Future<Set<String>> edgesIn(WidgetTester tester, Rect rect) async {
    final frame = await grabFrame(tester, ratio: 2);
    final inset = Offset(rect.width * .015, rect.height * .015);
    return {
      if (frame.near(
        Offset(rect.left + inset.dx, rect.center.dy),
        Visual.edgeLeft,
      ))
        'left',
      if (frame.near(
        Offset(rect.right - inset.dx, rect.center.dy),
        Visual.edgeRight,
      ))
        'right',
      if (frame.near(Offset(rect.center.dx, rect.top + inset.dy), Visual.edgeTop))
        'top',
      if (frame.near(
        Offset(rect.center.dx, rect.bottom - inset.dy),
        Visual.edgeBottom,
      ))
        'bottom',
    };
  }

  testVisual('a video work shows its whole 16:9 cover', (tester) async {
    await pumpDiagnostic(tester);
    await reveal(tester, tileOf('90000101'));
    final cover = coverOf(tester, '90000101');
    expect(cover.width / cover.height, closeTo(16 / 9, .02));
    expect(await edgesIn(tester, cover), {'left', 'right', 'top', 'bottom'});
    await shoot(tester, 'diag-grid', view);
  });

  testVisual('every tile in a row keeps one extent, whatever its type', (
    tester,
  ) async {
    await pumpDiagnostic(tester);
    final heights = {
      for (final element in find.byType(FanartCard).evaluate())
        tester.getSize(find.byWidget(element.widget)).height,
    };
    expect(heights, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testVisual('a portrait image keeps its top and both sides in the tile', (
    tester,
  ) async {
    await pumpDiagnostic(tester);
    await reveal(tester, tileOf('90000102'));
    final edges = await edgesIn(tester, coverOf(tester, '90000102'));
    expect(edges, containsAll(['left', 'right', 'top']));
  });

  testVisual('the detail shows a landscape image whole', (tester) async {
    await pumpDiagnostic(tester);
    await reveal(tester, tileOf('90000106'));
    await tester.tap(tileOf('90000106'));
    await settleVisual(tester);
    final image = tester.getRect(find.byType(Image).first);
    expect(await edgesIn(tester, image), {'left', 'right', 'top', 'bottom'});
  });

  testVisual('a long strip leaves the author and words on the first screen', (
    tester,
  ) async {
    await pumpDiagnostic(tester);
    await reveal(tester, tileOf('90000103'));
    await tester.tap(tileOf('90000103'));
    await settleVisual(tester);
    expect(find.byType(FanartDetailPage), findsOneWidget);
    // The words sit within the first screen, below a preview of the strip.
    final words = find.text('六格长条漫：第一格在最上面，作者和正文不应被推到很远');
    expect(words, findsOneWidget);
    expect(tester.getRect(words).bottom, lessThan(view.size.height - 80));
    await shoot(tester, 'diag-detail-strip', view);
    // The whole strip is one tap away, in the viewer that zooms.
    await tester.tap(find.text('看完整长图'));
    await settleVisual(tester);
    expect(find.byType(FanartImageViewer), findsOneWidget);
  });

  testVisual('an ordinary portrait is shown whole, not called long', (
    tester,
  ) async {
    await pumpDiagnostic(tester);
    await reveal(tester, tileOf('90000102'));
    await tester.tap(tileOf('90000102'));
    await settleVisual(tester);
    // 900x1600 at 358 wide is 636 tall: past the 464 cap, but not long.
    expect(find.text('看完整长图'), findsNothing);
    final image = tester.getRect(find.byType(Image).first);
    expect(image.height, greaterThan(600));
    expect(await edgesIn(tester, image), {'left', 'right', 'top', 'bottom'});
    await shoot(tester, 'diag-detail-portrait', view);
  });

  testVisual('diagnostic grid at 320 with 2x text', (tester) async {
    final narrow = VisualView.narrow.scaled(2);
    await pumpDiagnostic(tester, v: narrow);
    expect(tester.takeException(), isNull);
    await shoot(tester, 'diag-grid', narrow);
  });
}
