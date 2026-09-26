import 'package:asasfans_next/shared/widgets/media_grid_delegate.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

SliverConstraints _constraints({bool reverse = false}) => SliverConstraints(
  axisDirection: AxisDirection.down,
  growthDirection: GrowthDirection.forward,
  userScrollDirection: ScrollDirection.idle,
  scrollOffset: 0,
  precedingScrollExtent: 0,
  overlap: 0,
  remainingPaintExtent: 600,
  crossAxisExtent: 412,
  crossAxisDirection: reverse ? AxisDirection.left : AxisDirection.right,
  viewportMainAxisExtent: 600,
  remainingCacheExtent: 850,
  cacheOrigin: 0,
);

void main() {
  test('wide spacing and card geometry use the same available width', () {
    final columns = MediaGridDelegate.columnsFor(1100);
    final gap = MediaGridDelegate.spacingFor(1100);
    expect(gap, 16);
    expect(
      MediaGridDelegate.cellWidth(1100, columns) * columns +
          gap * (columns - 1),
      closeTo(1068, .001),
    );
    expect(MediaGridDelegate.spacingFor(390), 12);
  });
  test(
    'row maximums protect tall artwork while short text cards keep their own height',
    () {
      final layout = MediaGridDelegate(
        crossAxisCount: 2,
        itemExtents: [100, 200, 90],
      ).getLayout(_constraints());
      expect(layout.getGeometryForChildIndex(0).mainAxisExtent, 100);
      expect(layout.getGeometryForChildIndex(1).mainAxisExtent, 200);
      expect(layout.getGeometryForChildIndex(1).crossAxisOffset, 212);
      expect(layout.getGeometryForChildIndex(2).scrollOffset, 212);
      expect(layout.getGeometryForChildIndex(2).crossAxisExtent, 200);
      expect(layout.computeMaxScrollOffset(3), 302);
      expect(layout.getMinChildIndexForScrollOffset(170), 0);
      expect(layout.getMaxChildIndexForScrollOffset(250), 2);
    },
  );
  test(
    'empty grids and end sentinels are valid even before a sliver asks for its child count',
    () {
      final layout = MediaGridDelegate(
        crossAxisCount: 2,
        itemExtents: [],
      ).getLayout(_constraints());
      expect(layout.getGeometryForChildIndex(0).mainAxisExtent, 0);
      expect(layout.computeMaxScrollOffset(0), 0);
    },
  );
  test(
    'RTL mirrors columns without changing reading order or vertical extents',
    () {
      final layout = MediaGridDelegate(
        crossAxisCount: 2,
        itemExtents: [100, 200],
      ).getLayout(_constraints(reverse: true));
      expect(layout.getGeometryForChildIndex(0).crossAxisOffset, 212);
      expect(layout.getGeometryForChildIndex(1).crossAxisOffset, 0);
    },
  );
  test(
    'scrolling reuses row geometry rather than rescanning the whole feed each frame',
    () {
      final delegate = MediaGridDelegate(
        crossAxisCount: 2,
        itemExtents: [100, 200],
      );
      final first = delegate.getLayout(_constraints());
      expect(identical(first, delegate.getLayout(_constraints())), isTrue);
      expect(
        identical(first, delegate.getLayout(_constraints(reverse: true))),
        isFalse,
      );
    },
  );
  test('columns follow readable minimums and reduce for larger text', () {
    expect(MediaGridDelegate.columnsFor(320), 1);
    expect(MediaGridDelegate.columnsFor(390), 2);
    expect(MediaGridDelegate.columnsFor(390, textScale: 2), 1);
    expect(MediaGridDelegate.columnsFor(1600), 5);
  });

  test(
    'the fixed-extent video grid lays out exactly like per-item extents',
    () {
      for (final width in [320.0, 390.0, 760.0, 1100.0, 1400.0]) {
        for (final scale in [1.0, 1.3, 2.0]) {
          final scaler = TextScaler.linear(scale);
          final columns = MediaGridDelegate.columnsFor(width, textScale: scale);
          final cell = MediaGridDelegate.cellWidth(width, columns);
          final gap = MediaGridDelegate.spacingFor(width);
          // VideoCard.extentForWidth's formula, restated so the test does not
          // depend on the widget library.
          final meta = (scaler.scale(12) * 1.35).ceilToDouble();
          final extent =
              cell / (16 / 9) +
              8 +
              (scaler.scale(14) * 1.4).ceilToDouble() * 2 +
              2 +
              meta +
              (meta + 8 < 48 ? 48 : meta + 8);
          final constraints = _constraints().copyWith(
            crossAxisExtent: width - 32,
          );
          final before = MediaGridDelegate(
            crossAxisCount: columns,
            spacing: gap,
            itemExtents: List.filled(41, extent),
          ).getLayout(constraints);
          final after = SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            mainAxisExtent: extent,
          ).getLayout(constraints);
          for (var index = 0; index < 41; index++) {
            final a = before.getGeometryForChildIndex(index);
            final b = after.getGeometryForChildIndex(index);
            expect(b.scrollOffset, closeTo(a.scrollOffset, 1e-6));
            expect(b.crossAxisOffset, closeTo(a.crossAxisOffset, 1e-6));
            expect(b.mainAxisExtent, closeTo(a.mainAxisExtent, 1e-6));
            expect(b.crossAxisExtent, closeTo(a.crossAxisExtent, 1e-6));
          }
          expect(
            after.computeMaxScrollOffset(41),
            closeTo(before.computeMaxScrollOffset(41), 1e-6),
          );
        }
      }
    },
  );
}
