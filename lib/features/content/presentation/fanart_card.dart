import 'package:flutter/material.dart';

import '../domain/fanart_repository.dart';

/// Compact fanart tile. Images come from third-party CDNs, so a failed load
/// degrades to a labelled placeholder instead of an empty box, and the source
/// text stays readable on its own.
class FanartCard extends StatelessWidget {
  const FanartCard({required this.item, this.onTap, super.key});

  final FanartItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cover = item.images.firstOrNull;
    return Card(
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: cover == null
                  ? _Placeholder(item: item)
                  : Image.network(
                      cover.toString(),
                      fit: BoxFit.cover,
                      // Decode near display size to bound list image memory.
                      cacheWidth: 640,
                      errorBuilder: (context, error, stack) =>
                          _Placeholder(item: item),
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                          ? child
                          : ColoredBox(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: const Center(
                                child: SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.text.trim().isNotEmpty)
                    Text(
                      item.text.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.authorName.isEmpty ? '未知作者' : item.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      if (item.contentType == FanartContentType.video)
                        Icon(
                          Icons.play_circle_outline,
                          size: 16,
                          color: theme.colorScheme.outline,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.item});
  final FanartItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(switch (item.contentType) {
          FanartContentType.video => Icons.movie_outlined,
          FanartContentType.text => Icons.article_outlined,
          _ => Icons.image_not_supported_outlined,
        }, color: theme.colorScheme.outline),
      ),
    );
  }
}
