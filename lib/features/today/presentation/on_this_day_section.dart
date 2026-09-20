import '../../creator/presentation/creator_link.dart';
import '../../rules/presentation/rule_filter_scope.dart';
import '../../rules/application/feed_visibility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/application/content_snapshots.dart';
import '../../library/presentation/content_actions.dart';
import '../../library/presentation/library_common.dart';
import '../../../core/network/api_failure.dart';
import '../../content/application/content_providers.dart';
import '../../content/domain/dynamic_repository.dart';

/// "On this day" module for the home page.
///
/// It loads and fails on its own: an unavailable source shows an inline retry
/// here and never blanks the rest of the page or raises a global alert.
class OnThisDaySection extends ConsumerWidget {
  const OnThisDaySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(onThisDayProvider);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text('历史上的今天', style: theme.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 12),
        posts.when(
          loading: () => const SizedBox(
            height: 188,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => _SectionError(
            message: error is ApiFailure ? error.message : '内容加载失败',
            onRetry: () => ref.invalidate(onThisDayProvider),
          ),
          data: (raw) => RuleFilterScope(
            items: raw,
            subjectOf: RuleSubjects.dynamic,
            builder: (visible) => Column(
              children: [
                RuleStatusBar(visibility: visible),
                SizedBox(
                  height:
                      188 *
                      MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6),
                  child: _posts(context, visible.items),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _posts(BuildContext context, List<DynamicPost> items) {
    final theme = Theme.of(context);
    return items.isEmpty
        ? Center(
            child: Text(
              '往年今天还没有记录',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          )
        // Trailing padding so the last card ends clear of the edge
        // rather than looking clipped by the page margin.
        : ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 4),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _PostCard(post: items[index]),
          );
  }
}

class _PostCard extends ConsumerWidget {
  const _PostCard({required this.post});
  final DynamicPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final image = post.images.firstOrNull;
    return SizedBox(
      width: 220,
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: theme.colorScheme.surfaceContainerLow,
        child: InkWell(
          onTap: post.sourceUrl == null
              ? null
              : () => openContentSource(
                  context,
                  ref,
                  ContentSnapshots.dynamic(post),
                  url: post.sourceUrl,
                ),
          onLongPress: () => showContentActions(
            context,
            ContentSnapshots.dynamic(post),
            ruleSubject: RuleSubjects.dynamic(post),
          ),
          onSecondaryTap: () => showContentActions(
            context,
            ContentSnapshots.dynamic(post),
            ruleSubject: RuleSubjects.dynamic(post),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (image != null)
                SizedBox(
                  height: 96,
                  width: double.infinity,
                  child: Image.network(
                    image.toString(),
                    fit: BoxFit.cover,
                    cacheWidth: 440,
                    errorBuilder: (context, error, stack) => ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CreatorLink(
                        mid: post.member.bilibiliUid,
                        child: Text(
                          _header(post),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Text(
                          post.text.trim().isEmpty ? '（无正文）' : post.text.trim(),
                          maxLines: image == null ? 4 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Years are shown in the source's Shanghai calendar so the label matches
  /// the day the endpoint actually selected.
  static String _header(DynamicPost post) {
    final published = post.publishedAt;
    if (published == null) return post.member.name;
    final shanghai = published.add(const Duration(hours: 8));
    return '${shanghai.year} 年 · ${post.member.name}';
  }
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: onRetry, child: const Text('重试')),
      ],
    ),
  );
}
