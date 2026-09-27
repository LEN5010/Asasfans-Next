import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// Row-ordered, lazy media grid with per-card extents. Media keeps its own
/// aspect ratio; text-only cards do not need a fabricated cover to fill a cell.
class MediaGridDelegate extends SliverGridDelegate {
  MediaGridDelegate({
    required this.crossAxisCount,
    required List<double> itemExtents,
    this.spacing = 12,
  }) : assert(crossAxisCount > 0),
       assert(spacing >= 0),
       itemExtents = List.unmodifiable(itemExtents);
  final int crossAxisCount;
  final List<double> itemExtents;
  final double spacing;
  final _cache = _LayoutCache();

  static int columnsFor(double width, {double textScale = 1}) {
    final preferred = switch (width) {
      >= 1400 => 5,
      >= 1100 => 4,
      >= 760 => 3,
      _ => 2,
    };
    final minimum = (width >= 760 ? 220 : 160) * textScale.clamp(1.0, 1.5);
    final gap = spacingFor(width);
    return math.max(
      1,
      math.min(preferred, ((width - 32 + gap) / (minimum + gap)).floor()),
    );
  }

  static double spacingFor(double width) => width >= 760 ? 16 : 12;

  static double cellWidth(double width, int columns) =>
      math.max(0, width - 32 - (columns - 1) * spacingFor(width)) / columns;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final width = constraints.crossAxisExtent;
    final reverse = axisDirectionIsReversed(constraints.crossAxisDirection);
    if (_cache.layout == null ||
        _cache.width != width ||
        _cache.reverse != reverse) {
      _cache.width = width;
      _cache.reverse = reverse;
      _cache.layout = _MediaGridLayout(
        columns: crossAxisCount,
        heights: itemExtents,
        spacing: spacing,
        width: width,
        reverse: reverse,
      );
    }
    return _cache.layout!;
  }

  @override
  bool shouldRelayout(MediaGridDelegate oldDelegate) =>
      crossAxisCount != oldDelegate.crossAxisCount ||
      spacing != oldDelegate.spacing ||
      !listEquals(itemExtents, oldDelegate.itemExtents);
}

class _LayoutCache {
  double? width;
  bool? reverse;
  SliverGridLayout? layout;
}

class _MediaGridLayout extends SliverGridLayout {
  _MediaGridLayout({
    required this.columns,
    required this.heights,
    required this.spacing,
    required this.width,
    required this.reverse,
  }) {
    var offset = 0.0;
    for (var index = 0; index < heights.length; index += columns) {
      starts.add(offset);
      final height = heights.skip(index).take(columns).reduce(math.max);
      offset += height + spacing;
    }
    extent = starts.isEmpty ? 0 : offset - spacing;
  }
  final int columns;
  final List<double> heights;
  final double spacing;
  final double width;
  final bool reverse;
  final starts = <double>[];
  late final double extent;

  int _row(double offset) {
    var low = 0;
    var high = starts.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (starts[middle] <= offset) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return math.max(0, low - 1);
  }

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset) =>
      _row(scrollOffset) * columns;
  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset) => math.max(
    0,
    math.min(heights.length - 1, (_row(scrollOffset) + 1) * columns - 1),
  );
  @override
  double computeMaxScrollOffset(int childCount) => childCount == 0 ? 0 : extent;
  @override
  SliverGridGeometry getGeometryForChildIndex(int index) {
    final cellWidth = math.max(
      0.0,
      (width - spacing * (columns - 1)) / columns,
    );
    final column = index % columns;
    if (index >= heights.length) {
      return SliverGridGeometry(
        scrollOffset: extent,
        crossAxisOffset: 0,
        mainAxisExtent: 0,
        crossAxisExtent: cellWidth,
      );
    }
    return SliverGridGeometry(
      scrollOffset: starts[index ~/ columns],
      crossAxisOffset:
          (reverse ? columns - column - 1 : column) * (cellWidth + spacing),
      mainAxisExtent: heights[index],
      crossAxisExtent: cellWidth,
    );
  }
}
