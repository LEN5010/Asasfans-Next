import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'media_grid_delegate.dart';

/// Shared feed sizing, not a layout engine: the package measures real children
/// lazily inside the existing scroll view and retains their column positions.
/// Each child keeps its own height; columns come from the width actually
/// available (after any rail), never from the platform's name.
class SliverContentMasonry extends StatelessWidget {
  const SliverContentMasonry({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.minColumnWidth = 136,
    this.wideMinColumnWidth = 200,
    this.maxColumns = 6,
    this.rows,
  });
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// The narrowest a column may get, below and from [wide] width. Large
  /// text widens it (up to 1.6x), so words keep a readable measure. It only
  /// takes columns away: how many there are follows the video grid
  /// ([MediaGridDelegate.preferredColumns]).
  final double minColumnWidth;
  final double wideMinColumnWidth;
  final int maxColumns;

  /// For a finite section: at most this many rows' worth of items (columns
  /// times rows), in order. Null shows every item.
  final int? rows;

  static const wide = 760.0;

  static double spacingFor(double width) => width >= wide ? 16 : 12;

  static int columnsFor(
    double width,
    TextScaler scaler, {
    double minColumnWidth = 136,
    double wideMinColumnWidth = 200,
    int maxColumns = 6,
  }) {
    final gap = spacingFor(width);
    final minimum =
        (width >= wide ? wideMinColumnWidth : minColumnWidth) *
        scaler.scale(1).clamp(1.0, 1.6);
    final fit = ((width + gap) / (minimum + gap)).floor();
    return math
        .min(MediaGridDelegate.preferredColumns(width), fit)
        .clamp(1, maxColumns);
  }

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.crossAxisExtent;
      final gap = spacingFor(width);
      final columns = columnsFor(
        width,
        MediaQuery.textScalerOf(context),
        minColumnWidth: minColumnWidth,
        wideMinColumnWidth: wideMinColumnWidth,
        maxColumns: maxColumns,
      );
      final limit = rows;
      return SliverMasonryGrid.count(
        crossAxisCount: columns,
        // A little more between rows than columns: a byline reads with the
        // work above it, not the one below.
        mainAxisSpacing: gap + 4,
        crossAxisSpacing: gap,
        childCount: limit == null
            ? itemCount
            : math.min(itemCount, columns * limit),
        itemBuilder: itemBuilder,
      );
    },
  );
}
