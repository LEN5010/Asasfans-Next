import '../../rules/application/feed_visibility.dart';
import '../../rules/presentation/rule_filter_scope.dart';

import 'package:flutter/material.dart';

import '../../../shared/widgets/app_controls.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/auto_fill_viewport.dart';
import '../../../shared/widgets/feed_scroll_view.dart';
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
  const CommunityFeedView({
    this.channel = CommunityChannel.clips,
    this.onChannel,
    super.key,
  });
  final CommunityChannel channel;

  /// Switches the kind of video; the kinds are filters of one video channel.
  final ValueChanged<CommunityChannel>? onChannel;

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
      final order = _FilterRow(
        channel: widget.channel,
        onChannel: widget.onChannel,
        query: state.query,
        onChanged: _applyQuery,
        onRefresh: state.isBusy ? null : _controller.refresh,
      );
      return RuleFilterScope(
        items: state.videos,
        subjectOf: RuleSubjects.video,
        unavailableBuilder: (status) => FeedScrollView(
          controller: _scrollController,
          onRefresh: _controller.refresh,
          header: [order],
          placeholder: status,
        ),
        builder: (visible) => AutoFillViewport(
          controller: _scrollController,
          resetKey: (_controller.generation, visible.epoch),
          scrollResetKey: state.query,
          canLoadMore: state.status == FeedStatus.ready,
          onLoadMore: () => _controller.loadMore(automatic: true),
          child: _buildBody(state.copyWith(videos: visible.items), [
            order,
            RuleStatusBar(visibility: visible),
          ]),
        ),
      );
    },
  );

  Widget _buildBody(CommunityFeedState state, List<Widget> header) {
    final noun = switch (widget.channel) {
      CommunityChannel.clips => '切片',
      CommunityChannel.replays => '录播',
      _ => '视频',
    };
    final placeholder = state.videos.isNotEmpty
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
            FeedStatus.endOfList => FeedMessage(
              icon: Icons.search_off_outlined,
              text: '没有符合条件的$noun',
            ),
            _ => null,
          };
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
        return FeedScrollView(
          storageKey: PageStorageKey('community-${widget.channel.name}'),
          controller: _scrollController,
          onRefresh: _controller.refresh,
          header: header,
          placeholder: placeholder,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              sliver: SliverGrid.builder(
                gridDelegate: MediaGridDelegate(
                  spacing: MediaGridDelegate.spacingFor(constraints.maxWidth),
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
                    // These enum names are the route slugs, and the restorer
                    // resolves whatever it is given through ContentChannel,
                    // so a rename lands on the channel list rather than a
                    // broken route.
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
          ],
        );
      },
    );
  }
}

/// Kind, order and time window in one row: the kinds as chips, the rest as
/// compact menus so the row does not outgrow a phone.
class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.channel,
    required this.onChannel,
    required this.query,
    required this.onChanged,
    required this.onRefresh,
  });

  final VoidCallback? onRefresh;
  final CommunityChannel channel;
  final ValueChanged<CommunityChannel>? onChannel;
  final CommunityVideoQuery query;
  final ValueChanged<CommunityVideoQuery> onChanged;

  static const _kinds = {
    CommunityChannel.latest: '全部',
    CommunityChannel.clips: '切片',
    CommunityChannel.replays: '录播',
  };
  static const _orders = {
    CommunityVideoOrder.newest: '最新',
    CommunityVideoOrder.score: '最热',
  };
  // 0 stands for no window: a menu cannot return null as a choice.
  static const _windows = {0: '全部时间', 7: '一周内', 30: '一月内'};

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
    child: Row(
      spacing: 8,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 240,
              child: AppSegments<CommunityChannel>(
                values: _kinds.keys.toList(),
                selected: channel,
                labelOf: (value) => _kinds[value]!,
                onChanged: onChannel,
              ),
            ),
          ),
        ),
        MenuAnchor(
          menuChildren: [
            for (final entry in _orders.entries)
              MenuItemButton(
                onPressed: () => onChanged(query.copyWith(order: entry.key)),
                leadingIcon: Icon(
                  query.order == entry.key ? Icons.check : Icons.sort,
                ),
                child: Text(entry.value),
              ),
            const Divider(),
            for (final entry in _windows.entries)
              MenuItemButton(
                onPressed: () => onChanged(
                  entry.key == 0
                      ? query.copyWith(clearDays: true)
                      : query.copyWith(withinDays: entry.key),
                ),
                leadingIcon: Icon(
                  (query.withinDays ?? 0) == entry.key
                      ? Icons.check
                      : Icons.date_range,
                ),
                child: Text(entry.value),
              ),
          ],
          builder: (context, menu, _) => AppButton.icon(
            tooltip: '筛选与排序',
            selected:
                query.order != CommunityVideoOrder.newest ||
                query.withinDays != null,
            icon: const Icon(Icons.tune),
            onPressed: () => menu.isOpen ? menu.close() : menu.open(),
          ),
        ),
        AppButton.icon(
          tooltip: '刷新',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
  );
}
