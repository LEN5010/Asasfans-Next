import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

/// Shared feed sizing, not a layout engine: the package measures real children
/// lazily inside the existing scroll view and retains their column positions.
class SliverContentMasonry extends StatelessWidget {
  const SliverContentMasonry({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.minColumnWidth = 340,
  });
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double minColumnWidth;

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.crossAxisExtent;
      final spacing = width >= 760 ? 20.0 : 12.0;
      final minWidth =
          minColumnWidth * MediaQuery.textScalerOf(context).scale(1);
      final columns = ((width + spacing) / (minWidth + spacing)).floor().clamp(
        1,
        4,
      );
      return SliverMasonryGrid.count(
        crossAxisCount: columns,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childCount: itemCount,
        itemBuilder: itemBuilder,
      );
    },
  );
}
