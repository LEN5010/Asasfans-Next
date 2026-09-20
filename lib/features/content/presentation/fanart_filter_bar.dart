import 'package:flutter/material.dart';

import '../domain/fanart_repository.dart';

/// Compact filter row for the fanart feed.
///
/// Only combinations the server accepts can be produced: selecting a metric
/// sort restricts the query to videos, and leaving video content clears a
/// metric sort, so the user never triggers a rejected request.
class FanartFilterBar extends StatelessWidget {
  const FanartFilterBar({
    required this.query,
    required this.onChanged,
    super.key,
  });

  final FanartQuery query;
  final ValueChanged<FanartQuery> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final character in FanartCharacter.values) ...[
            FilterChip(
              label: Text(character.wire),
              selected: query.characters.contains(character),
              // Multiple characters mean "matches all of them" server-side.
              onSelected: (selected) => onChanged(
                query.copyWith(
                  characters: {
                    for (final value in query.characters)
                      if (selected || value != character) value,
                    if (selected) character,
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          const _Divider(),
          _ContentTypeMenu(query: query, onChanged: onChanged),
          const SizedBox(width: 8),
          _CategoryMenu(query: query, onChanged: onChanged),
          const SizedBox(width: 8),
          _SortMenu(query: query, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: SizedBox(
      height: 20,
      child: VerticalDivider(
        width: 8,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    ),
  );
}

class _ContentTypeMenu extends StatelessWidget {
  const _ContentTypeMenu({required this.query, required this.onChanged});

  final FanartQuery query;
  final ValueChanged<FanartQuery> onChanged;

  static const _labels = {
    FanartContentType.all: '全部类型',
    FanartContentType.image: '图片',
    FanartContentType.video: '视频',
    FanartContentType.text: '文字',
    FanartContentType.other: '其他',
  };

  @override
  Widget build(BuildContext context) => PopupMenuButton<FanartContentType>(
    tooltip: '媒体类型',
    initialValue: query.contentType,
    onSelected: (value) {
      // Metric sorts only exist for videos; leaving video resets the sort.
      final sort = value == FanartContentType.video
          ? query.sort
          : (query.usesMetricSort ? FanartSort.newest : query.sort);
      onChanged(query.copyWith(contentType: value, sort: sort));
    },
    itemBuilder: (context) => [
      for (final entry in _labels.entries)
        PopupMenuItem(value: entry.key, child: Text(entry.value)),
    ],
    child: _Trigger(label: _labels[query.contentType]!),
  );
}

class _CategoryMenu extends StatelessWidget {
  const _CategoryMenu({required this.query, required this.onChanged});

  final FanartQuery query;
  final ValueChanged<FanartQuery> onChanged;

  @override
  Widget build(BuildContext context) => PopupMenuButton<FanartCategory>(
    tooltip: '细分类',
    initialValue: query.category,
    onSelected: (value) => onChanged(query.copyWith(category: value)),
    itemBuilder: (context) => [
      for (final value in FanartCategory.values)
        PopupMenuItem(
          value: value,
          child: Text(value == FanartCategory.all ? '全部分类' : value.wire),
        ),
    ],
    child: _Trigger(
      label: query.category == FanartCategory.all
          ? '全部分类'
          : query.category.wire,
    ),
  );
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.query, required this.onChanged});

  final FanartQuery query;
  final ValueChanged<FanartQuery> onChanged;

  static const _labels = {
    FanartSort.newest: '最新',
    FanartSort.oldest: '最早',
    FanartSort.views: '播放最多',
    FanartSort.favorites: '收藏最多',
  };

  @override
  Widget build(BuildContext context) => PopupMenuButton<FanartSort>(
    tooltip: '排序',
    initialValue: query.sort,
    onSelected: (value) {
      final metric = value == FanartSort.views || value == FanartSort.favorites;
      onChanged(
        query.copyWith(
          sort: value,
          // The server rejects a metric sort outside video content, so
          // choosing one narrows the query instead of failing the request.
          contentType: metric ? FanartContentType.video : query.contentType,
          source: metric && query.source == FanartSource.douban
              ? FanartSource.all
              : query.source,
        ),
      );
    },
    itemBuilder: (context) => [
      for (final entry in _labels.entries)
        PopupMenuItem(value: entry.key, child: Text(entry.value)),
    ],
    child: _Trigger(label: _labels[query.sort]!),
  );
}

class _Trigger extends StatelessWidget {
  const _Trigger({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 2),
          Icon(
            Icons.arrow_drop_down,
            size: 18,
            color: theme.colorScheme.outline,
          ),
        ],
      ),
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      side: BorderSide.none,
    );
  }
}
