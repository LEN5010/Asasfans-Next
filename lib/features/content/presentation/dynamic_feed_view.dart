import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../application/content_providers.dart';
import '../application/dynamic_feed_controller.dart';
import '../application/fanart_feed_controller.dart' show FeedStatus;
import '../domain/dynamic_repository.dart';

/// Historical dynamics list with keyword search and auto-append.
class DynamicFeedView extends ConsumerStatefulWidget {
  const DynamicFeedView({super.key});

  @override
  ConsumerState<DynamicFeedView> createState() => _DynamicFeedViewState();
}

class _DynamicFeedViewState extends ConsumerState<DynamicFeedView> {
  final _scrollController = ScrollController();
  late final DynamicFeedController _controller = ref.read(
    dynamicFeedControllerProvider,
  );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.loadInitial();
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 600) {
      _controller.loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _applyQuery(DynamicQuery query) {
    _controller.applyQuery(query);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final state = _controller.state;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              textInputAction: TextInputAction.search,
              maxLength: 200,
              decoration: const InputDecoration(
                hintText: '搜索历史动态',
                counterText: '',
                isDense: true,
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (keyword) =>
                  _applyQuery(state.query.copyWith(keyword: keyword)),
            ),
          ),
          const SizedBox(height: 8),
          _TypeFilter(query: state.query, onChanged: _applyQuery),
          const SizedBox(height: 8),
          Expanded(child: _buildBody(state)),
        ],
      );
    },
  );

  Widget _buildBody(DynamicFeedState state) {
    if (state.items.isEmpty) {
      return switch (state.status) {
        FeedStatus.failed => _Error(
          message: state.failure?.message ?? '内容加载失败',
          onRetry: _controller.refresh,
        ),
        FeedStatus.idle || FeedStatus.loadingFirstPage => const Center(
          child: CircularProgressIndicator(),
        ),
        _ => const Center(child: Text('没有符合条件的动态')),
      };
    }
    return RefreshIndicator(
      onRefresh: _controller.refresh,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: state.items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) => index == state.items.length
            ? _Footer(state: state, onRetry: _controller.loadMore)
            : _DynamicCard(post: state.items[index]),
      ),
    );
  }
}

class _TypeFilter extends StatelessWidget {
  const _TypeFilter({required this.query, required this.onChanged});

  final DynamicQuery query;
  final ValueChanged<DynamicQuery> onChanged;

  static const _labels = {
    DynamicType.image: '图文',
    DynamicType.video: '视频',
    DynamicType.forward: '转发',
    DynamicType.article: '专栏',
    DynamicType.text: '文字',
  };

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        ChoiceChip(
          label: const Text('全部'),
          selected: query.type == null,
          onSelected: (_) => onChanged(query.copyWith(clearType: true)),
        ),
        for (final entry in _labels.entries) ...[
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text(entry.value),
            selected: query.type == entry.key,
            onSelected: (selected) => onChanged(
              selected
                  ? query.copyWith(type: entry.key)
                  : query.copyWith(clearType: true),
            ),
          ),
        ],
      ],
    ),
  );
}

class _DynamicCard extends ConsumerWidget {
  const _DynamicCard({required this.post});
  final DynamicPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final forwarded = post.forwardedFrom;
    return Card(
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: post.sourceUrl == null
            ? null
            : () => ref.read(externalLinkServiceProvider).open(post.sourceUrl!),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      post.member.name,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  if (post.publishedAt != null)
                    Text(
                      _shanghaiDate(post.publishedAt!),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                ],
              ),
              if (post.text.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  post.text.trim(),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              // A repost shows its origin rather than passing the original
              // content off as the forwarding member's own.
              if (forwarded != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        forwarded.authorName.isEmpty
                            ? '原动态'
                            : '@${forwarded.authorName}',
                        style: theme.textTheme.labelSmall,
                      ),
                      if (forwarded.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          forwarded.text.trim(),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (post.images.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 110,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: post.images.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) => ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        post.images[index].toString(),
                        width: 110,
                        height: 110,
                        fit: BoxFit.cover,
                        cacheWidth: 320,
                        errorBuilder: (context, error, stack) => Container(
                          width: 110,
                          color: theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Source timestamps are UTC; the list labels them on the Shanghai calendar
  /// the archive is organised by.
  static String _shanghaiDate(DateTime utc) {
    final local = utc.add(const Duration(hours: 8));
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.state, required this.onRetry});

  final DynamicFeedState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => switch (state.status) {
    FeedStatus.appending => const Padding(
      padding: EdgeInsets.all(20),
      child: Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    ),
    FeedStatus.appendFailed => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            state.failure?.message ?? '加载失败',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    ),
    FeedStatus.endOfList => Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          '没有更多了',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
    ),
    _ => const SizedBox(height: 20),
  };
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.cloud_off_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(height: 16),
        Text(message),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: const Text('重试')),
      ],
    ),
  );
}
