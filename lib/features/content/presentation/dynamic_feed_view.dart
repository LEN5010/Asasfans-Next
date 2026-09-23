import '../../creator/presentation/creator_link.dart';
import '../../rules/application/feed_visibility.dart';
import '../../rules/presentation/rule_filter_scope.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/application/content_snapshots.dart';
import '../../library/presentation/content_actions.dart';
import '../../library/presentation/library_common.dart';
import '../../../shared/widgets/auto_fill_viewport.dart';
import '../../../shared/widgets/feed_scroll_view.dart';
import '../../../shared/widgets/media_card_surface.dart';
import '../application/content_providers.dart';
import '../application/dynamic_feed_controller.dart';
import '../application/fanart_feed_controller.dart' show FeedStatus;
import '../domain/dynamic_repository.dart';
import 'feed_status_footer.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.loadInitial();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
      final filters = _TypeFilter(query: state.query, onChanged: _applyQuery);
      return RuleFilterScope(
        items: state.items,
        subjectOf: RuleSubjects.dynamic,
        unavailableBuilder: (status) => FeedScrollView(
          controller: _scrollController,
          onRefresh: _controller.refresh,
          header: [filters],
          placeholder: status,
        ),
        builder: (visible) => AutoFillViewport(
          controller: _scrollController,
          resetKey: (_controller.generation, visible.epoch),
          scrollResetKey: state.query,
          canLoadMore: state.status == FeedStatus.ready,
          onLoadMore: () => _controller.loadMore(automatic: true),
          child: _buildBody(state.copyWith(items: visible.items), [
            filters,
            RuleStatusBar(visibility: visible),
          ]),
        ),
      );
    },
  );

  Widget _buildBody(DynamicFeedState state, List<Widget> header) {
    final placeholder = state.items.isNotEmpty
        ? null
        : switch (state.status) {
            FeedStatus.failed => FeedMessage(
              icon: Icons.cloud_off_outlined,
              text: state.failure?.message ?? '内容加载失败',
              failure: state.failure,
              onRetry: _controller.refresh,
            ),
            FeedStatus.idle || FeedStatus.loadingFirstPage => const Center(
              child: CircularProgressIndicator(),
            ),
            FeedStatus.endOfList => const FeedMessage(
              icon: Icons.search_off_outlined,
              text: '没有符合条件的动态',
            ),
            _ => null,
          };
    return FeedScrollView(
      storageKey: const PageStorageKey('historical-dynamics-feed'),
      controller: _scrollController,
      onRefresh: _controller.refresh,
      header: header,
      placeholder: placeholder,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          // Text-led posts read best at a bounded measure on wide windows.
          sliver: SliverConstrainedCrossAxis(
            maxExtent: 760,
            sliver: SliverList.separated(
              itemCount: state.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _DynamicCard(post: state.items[index]),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: FeedStatusFooter(
            status: state.status,
            failure: state.failure,
            onRetry: _controller.loadMore,
            onRefresh: _controller.refresh,
          ),
        ),
      ],
    );
  }
}

class _TypeFilter extends ConsumerWidget {
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

  static String _day(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  /// The server rejects an inverted or empty range, so pick both ends at once
  /// and send them only as a complete, ordered pair.
  Future<void> _pickRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: query.from != null && query.to != null
          ? DateTimeRange(
              start: query.from!.toLocal(),
              end: query.to!.toLocal(),
            )
          : null,
    );
    if (picked == null) return;
    // Cover the whole end day: a date picker returns midnight, which would
    // otherwise drop everything posted on the final day.
    final to = DateTime(
      picked.end.year,
      picked.end.month,
      picked.end.day,
      23,
      59,
      59,
    );
    onChanged(query.copyWith(from: picked.start, to: to));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(dynamicMembersProvider);
    final selected = members.valueOrNull?.where(
      (member) => member.id == query.memberId,
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          if (query.keyword.isNotEmpty) ...[
            InputChip(
              label: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(query.keyword, overflow: TextOverflow.ellipsis),
              ),
              onDeleted: () => onChanged(query.copyWith(keyword: '')),
            ),
            const SizedBox(width: 8),
          ],
          if (query.memberId != null) ...[
            InputChip(
              avatar: const Icon(Icons.person_outline, size: 18),
              label: Text(selected?.firstOrNull?.name ?? '指定成员'),
              onDeleted: () => onChanged(query.copyWith(clearMember: true)),
            ),
            const SizedBox(width: 8),
          ],
          if (query.from != null && query.to != null) ...[
            InputChip(
              avatar: const Icon(Icons.date_range_outlined, size: 18),
              label: Text('${_day(query.from!)} ~ ${_day(query.to!)}'),
              onDeleted: () => onChanged(query.copyWith(clearRange: true)),
            ),
            const SizedBox(width: 8),
          ],
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
          const SizedBox(width: 8),
          ActionChip(
            avatar: const Icon(Icons.date_range_outlined, size: 18),
            label: const Text('时间范围'),
            onPressed: () => _pickRange(context),
          ),
          // A member filter needs a server-issued id, so offer it only once the
          // member list has actually loaded.
          if (members.valueOrNull case final roster?
              when roster.isNotEmpty) ...[
            const SizedBox(width: 8),
            PopupMenuButton<String?>(
              tooltip: '按成员筛选',
              onSelected: (value) => onChanged(
                value == null
                    ? query.copyWith(clearMember: true)
                    : query.copyWith(memberId: value),
              ),
              itemBuilder: (_) => [
                const PopupMenuItem(value: null, child: Text('全部成员')),
                for (final member in roster)
                  PopupMenuItem(value: member.id, child: Text(member.name)),
              ],
              child: const Chip(
                avatar: Icon(Icons.person_outline, size: 18),
                label: Text('成员'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DynamicCard extends ConsumerWidget {
  const _DynamicCard({required this.post});
  final DynamicPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final forwarded = post.forwardedFrom;
    void actions() => showContentActions(
      context,
      ContentSnapshots.dynamic(post),
      ruleSubject: RuleSubjects.dynamic(post),
    );
    return MediaCardSurface(
      onTap: post.sourceUrl == null
          ? null
          : () => openContentSource(
              context,
              ref,
              ContentSnapshots.dynamic(post),
              url: post.sourceUrl,
            ),
      onMore: actions,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CreatorLink(
                        mid: post.member.bilibiliUid,
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
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '更多操作',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.more_horiz),
                  onPressed: actions,
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
