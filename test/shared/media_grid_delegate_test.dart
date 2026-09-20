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
}
