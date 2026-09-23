import '../../rules/application/feed_visibility.dart';
import '../../rules/presentation/rule_filter_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../shared/widgets/auto_fill_viewport.dart';
import '../../../shared/widgets/retry_button.dart';
import '../../../shared/widgets/media_grid_delegate.dart';
import '../../handoff/domain/return_context.dart';
import '../../handoff/presentation/watch_on_bilibili.dart';
import 'video_card.dart';
import '../application/community_feed_controller.dart';
import '../application/content_providers.dart';
import '../application/fanart_feed_controller.dart' show FeedStatus;
import '../domain/community_video_repository.dart';
import 'feed_status_footer.dart';

/// Live clips list, backed by the community video index.
///
/// Channel alternatives are merged by the pager, separately from fanart.
class CommunityFeedView extends ConsumerStatefulWidget {
  const CommunityFeedView({this.channel = CommunityChannel.clips, super.key});
  final CommunityChannel channel;

  @override
  ConsumerState<CommunityFeedView> createState() => _CommunityFeedViewState();
}

class _CommunityFeedViewState extends ConsumerState<CommunityFeedView> {
  final _scrollController = ScrollController();
  late final CommunityFeedController _controller = ref.read(
    communityFeedControllerProvider(widget.channel),
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

  void _applyQuery(CommunityVideoQuery query) {
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
          _OrderRow(query: state.query, onChanged: _applyQuery),
          const SizedBox(height: 8),
          Expanded(
            child: RuleFilterScope(
              items: state.videos,
              subjectOf: RuleSubjects.video,
              builder: (visible) => Column(
                children: [
                  RuleStatusBar(visibility: visible),
                  Expanded(
                    child: AutoFillViewport(
                      controller: _scrollController,
                      resetKey: (_controller.generation, visible.epoch),
                      scrollResetKey: state.query,
                      canLoadMore: state.status == FeedStatus.ready,
                      onLoadMore: () => _controller.loadMore(automatic: true),
                      child: _buildBody(state.copyWith(videos: visible.items)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget _buildBody(CommunityFeedState state) {
    if (state.videos.isEmpty &&
        (state.status == FeedStatus.failed ||
            state.status == FeedStatus.idle ||
            state.status == FeedStatus.loadingFirstPage ||
            state.status == FeedStatus.endOfList)) {
      return switch (state.status) {
        FeedStatus.failed => _Error(
          failure: state.failure,
          onRetry: _controller.refresh,
        ),
        FeedStatus.idle || FeedStatus.loadingFirstPage => const Center(
          child: CircularProgressIndicator(),
        ),
        _ => Center(
          child: Text(
            '没有符合条件的${widget.channel == CommunityChannel.clips
                ? '切片'
                : widget.channel == CommunityChannel.replays
                ? '录播'
                : '视频'}',
          ),
        ),
      };
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final columns = MediaGridDelegate.columnsFor(
          constraints.maxWidth,
          textScale: scaler.scale(1),
        );
        final width = MediaGridDelegate.cellWidth(
          constraints.maxWidth,
          columns,
        );
        return RefreshIndicator(
          onRefresh: _controller.refresh,
          child: CustomScrollView(
            key: PageStorageKey('community-${widget.channel.name}'),
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                sliver: SliverGrid.builder(
                  gridDelegate: MediaGridDelegate(
                    crossAxisCount: columns,
                    itemExtents: [
                      for (final video in state.videos)
                        VideoCard.extentFor(video, width, scaler),
                    ],
                  ),
                  itemCount: state.videos.length,
                  itemBuilder: (_, index) => VideoCard(
                    video: state.videos[index],
                    origin: WatchOrigin(
                      target: ReturnTarget.contentChannel,
                      // These enum names are the route slugs, and the
                      // restorer resolves whatever it is given through
                      // ContentChannel, so a rename lands on the channel
                      // list rather than a broken route.
                      channel: widget.channel.name,
                      // Read at tap time, so the anchor is where the list
                      // actually is rather than where it was when this card
                      // was first built.
                      anchorOf: () => ReturnAnchor(
                        identity: state.videos[index].identity,
                        offset: _scrollController.hasClients
                            ? _scrollController.offset
                            : null,
                      ),
                    ),
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
              SliverToBoxAdapter(
                child: SizedBox(height: MediaQuery.paddingOf(context).bottom),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.query, required this.onChanged});

  final CommunityVideoQuery query;
  final ValueChanged<CommunityVideoQuery> onChanged;

  static const _windows = {7: '一周内', 30: '一月内'};

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        for (final order in CommunityVideoOrder.values) ...[
          ChoiceChip(
            label: Text(order == CommunityVideoOrder.newest ? '最新' : '最热'),
            selected: query.order == order,
            onSelected: (_) => onChanged(query.copyWith(order: order)),
          ),
          const SizedBox(width: 8),
        ],
        const SizedBox(width: 4),
        ChoiceChip(
          label: const Text('全部时间'),
          selected: query.withinDays == null,
          onSelected: (_) => onChanged(query.copyWith(clearDays: true)),
        ),
        for (final entry in _windows.entries) ...[
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text(entry.value),
            selected: query.withinDays == entry.key,
            onSelected: (selected) => onChanged(
              selected
                  ? query.copyWith(withinDays: entry.key)
                  : query.copyWith(clearDays: true),
            ),
          ),
        ],
      ],
    ),
  );
}

class _Error extends StatelessWidget {
  const _Error({required this.failure, required this.onRetry});
  final ApiFailure? failure;
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
        Text(failure?.message ?? '内容加载失败'),
        const SizedBox(height: 16),
        RetryButton(failure: failure, onRetry: onRetry, filled: true),
      ],
    ),
  );
}
