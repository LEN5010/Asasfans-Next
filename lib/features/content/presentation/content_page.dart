import '../../rules/application/rules_providers.dart';
import '../../rules/application/visible_random.dart';
import '../../rules/presentation/rule_common.dart';
import '../../subscriptions/presentation/subscription_feed_view.dart';
import '../../rules/application/feed_visibility.dart';
import '../../rules/presentation/rule_filter_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_failure.dart';
import '../../../shared/widgets/auto_fill_viewport.dart';
import '../../../shared/widgets/feature_pending.dart';
import '../../../shared/widgets/media_grid_delegate.dart';
import '../../../shared/widgets/retry_button.dart';
import '../application/content_providers.dart';
import '../application/fanart_feed_controller.dart';
import '../domain/fanart_repository.dart';
import 'community_feed_view.dart';
import 'content_search_control.dart';
import 'dynamic_feed_view.dart';
import 'fanart_card.dart';
import 'fanart_detail_page.dart';
import '../domain/saved_channel.dart';
import 'fanart_filter_bar.dart';
import 'saved_channel_bar.dart';
import 'feed_status_footer.dart';
import '../../library/application/content_snapshots.dart';
import '../../library/presentation/content_actions.dart';

class ContentPage extends ConsumerWidget {
  const ContentPage({this.channel = 'fanart', super.key});
  final String channel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ContentChannel.fromSlug(channel) ?? ContentChannel.fanart;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) => Padding(
                key: const ValueKey('content-toolbar'),
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(child: _ChannelStrip(current: current)),
                    const SizedBox(width: 6),
                    _headerActions(ref, current, constraints.maxWidth >= 1040),
                  ],
                ),
              ),
            ),
            Expanded(
              child: switch (current) {
                ContentChannel.subscriptions => const SubscriptionFeedView(),
                _ when current.isBackedByFanartApi => _FanartFeed(
                  channel: current,
                ),
                _ when current.isBackedByDynamicsApi => const DynamicFeedView(),
                _ when current.isBackedByCommunityApi => CommunityFeedView(
                  key: ValueKey(current),
                  channel: current.communityChannel!,
                ),
                _ => const FeaturePending(
                  icon: Icons.auto_awesome_mosaic_outlined,
                ),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerActions(WidgetRef ref, ContentChannel channel, bool wide) {
    if (channel == ContentChannel.subscriptions) return const SizedBox.shrink();
    if (channel.isBackedByFanartApi) {
      final controller = ref.watch(fanartFeedControllerProvider(channel));
      return ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ContentSearchControl(
              value: controller.state.query.keyword,
              hint: '搜索正文或作者',
              expanded: wide,
              onSubmitted: (keyword) => controller.applyQuery(
                controller.state.query.copyWith(keyword: keyword),
              ),
            ),
            FanartFilterButton(
              query: controller.state.query,
              onChanged: controller.applyQuery,
            ),
            _RandomFanartAction(channel: channel),
            if (wide)
              IconButton(
                tooltip: '刷新',
                onPressed: controller.state.isBusy ? null : controller.refresh,
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
      );
    }
    if (channel.isBackedByDynamicsApi) {
      final controller = ref.watch(dynamicFeedControllerProvider);
      return ListenableBuilder(
        listenable: controller,
        builder: (_, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ContentSearchControl(
              value: controller.state.query.keyword,
              hint: '搜索历史动态',
              expanded: wide,
              onSubmitted: (keyword) => controller.applyQuery(
                controller.state.query.copyWith(keyword: keyword),
              ),
            ),
            IconButton(
              tooltip: '刷新',
              onPressed: controller.state.isBusy ? null : controller.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      );
    }
    final controller = ref.watch(
      communityFeedControllerProvider(channel.communityChannel!),
    );
    return ListenableBuilder(
      listenable: controller,
      builder: (_, _) => IconButton(
        tooltip: '刷新',
        onPressed: controller.state.isBusy ? null : controller.refresh,
        icon: const Icon(Icons.refresh),
      ),
    );
  }
}

class _ChannelStrip extends StatefulWidget {
  const _ChannelStrip({required this.current});
  final ContentChannel current;
  @override
  State<_ChannelStrip> createState() => _ChannelStripState();
}

class _ChannelStripState extends State<_ChannelStrip> {
  final _selected = GlobalKey();
  @override
  void initState() {
    super.initState();
    _revealSelected();
  }

  @override
  void didUpdateWidget(_ChannelStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.current != oldWidget.current) _revealSelected();
  }

  void _revealSelected() => WidgetsBinding.instance.addPostFrameCallback((_) {
    final selectedContext = _selected.currentContext;
    if (mounted && selectedContext != null) {
      Scrollable.ensureVisible(selectedContext, alignment: .5);
    }
  });
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const PageStorageKey('content-channel-strip'),
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final value in ContentChannel.values)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              key: widget.current == value ? _selected : ValueKey(value),
              label: Text(value.label),
              selected: widget.current == value,
              onSelected: (_) => context.go('/content/${value.slug}'),
            ),
          ),
      ],
    ),
  );
}

/// Draws one random post and opens it directly.
///
/// Each draw is an independent request, so the button disables itself while
/// one is in flight instead of letting repeated taps stack up requests.
class _RandomFanartAction extends ConsumerStatefulWidget {
  const _RandomFanartAction({required this.channel});
  final ContentChannel channel;

  @override
  ConsumerState<_RandomFanartAction> createState() =>
      _RandomFanartActionState();
}

class _RandomFanartActionState extends ConsumerState<_RandomFanartAction> {
  bool _loading = false;
  RequestCancellation? _cancellation;

  @override
  void dispose() {
    _cancellation?.cancel();
    super.dispose();
  }

  Future<void> _draw() async {
    if (_loading) return;
    setState(() => _loading = true);
    final feed = ref.read(fanartFeedControllerProvider(widget.channel));
    final query = feed.state.query;
    final generation = feed.generation;
    try {
      final result = await drawVisibleFanart(
        ref.read(fanartRepositoryProvider),
        ref.read(rulesControllerProvider.notifier),
        query: query,
        cancellation: _cancellation = RequestCancellation(),
      );
      final item = result.item;
      if (!mounted || feed.generation != generation) return;
      if (item == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.filtered ? '本次结果均被屏蔽，请调整规则或重试' : '没有可用的二创'),
          ),
        );
        return;
      }
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(builder: (_) => FanartDetailPage(item: item)),
      );
    } on ApiFailure catch (failure) {
      if (!mounted ||
          feed.generation != generation ||
          failure.kind == ApiFailureKind.cancelled) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    } catch (error) {
      if (mounted && feed.generation == generation) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ruleError(error))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: '随机二创',
    onPressed: _loading ? null : _draw,
    icon: _loading
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.shuffle),
  );
}

/// Infinite fanart grid. Scroll position is owned by this widget so returning
/// to the channel restores where the user was, and the controller keeps its
/// already-loaded pages.
class _FanartFeed extends ConsumerStatefulWidget {
  const _FanartFeed({required this.channel});
  final ContentChannel channel;

  @override
  ConsumerState<_FanartFeed> createState() => _FanartFeedState();
}

class _FanartFeedState extends ConsumerState<_FanartFeed> {
  final _scrollController = ScrollController();
  late FanartFeedController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(fanartFeedControllerProvider(widget.channel));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.loadInitial();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Applying a filter starts a new query generation, so the view returns to
  /// the top rather than keeping an offset that belonged to the old result.
  void _applyQuery(FanartQuery query) {
    _controller.applyQuery(query);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final state = _controller.state;
        return Column(
          children: [
            FanartFilterBar(query: state.query, onChanged: _applyQuery),
            const SizedBox(height: 8),
            SavedChannelBar(
              feed: ChannelFeed.fanart,
              currentSpec: () => ChannelSpec.ofFanart(_controller.state.query),
              onOpen: (spec) => _applyQuery(spec.toFanart()),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: RuleFilterScope(
                items: state.items,
                subjectOf: RuleSubjects.fanart,
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
                        child: _buildBody(state.copyWith(items: visible.items)),
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
  }

  Widget _buildBody(FanartFeedState state) {
    if (state.items.isEmpty &&
        (state.status == FeedStatus.failed ||
            state.status == FeedStatus.idle ||
            state.status == FeedStatus.loadingFirstPage ||
            state.status == FeedStatus.endOfList)) {
      return switch (state.status) {
        FeedStatus.failed => _FeedError(
          failure: state.failure,
          onRetry: _controller.refresh,
        ),
        FeedStatus.idle || FeedStatus.loadingFirstPage => const Center(
          child: CircularProgressIndicator(),
        ),
        _ => RefreshIndicator(
          onRefresh: _controller.refresh,
          child: const CustomScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(hasScrollBody: false, child: _FeedEmpty()),
            ],
          ),
        ),
      };
    }
    return RefreshIndicator(
      onRefresh: _controller.refresh,
      child: _FanartGrid(
        state: state,
        controller: _scrollController,
        onRetryAppend: _controller.loadMore,
        onRefresh: _controller.refresh,
      ),
    );
  }
}

class _FanartGrid extends StatelessWidget {
  const _FanartGrid({
    required this.state,
    required this.controller,
    required this.onRetryAppend,
    required this.onRefresh,
  });

  final FanartFeedState state;
  final ScrollController controller;
  final VoidCallback onRetryAppend;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
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
        return CustomScrollView(
          key: const PageStorageKey('fanart-feed'),
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              sliver: SliverGrid.builder(
                gridDelegate: MediaGridDelegate(
                  crossAxisCount: columns,
                  itemExtents: [
                    for (final item in state.items)
                      FanartCard.extentFor(item, width, scaler),
                  ],
                ),
                itemCount: state.items.length,
                itemBuilder: (context, index) {
                  final item = state.items[index];
                  return FanartCard(
                    item: item,
                    onLongPress: () => showContentActions(
                      context,
                      ContentSnapshots.fanart(item),
                      ruleSubject: RuleSubjects.fanart(item),
                    ),
                    // Root route covers the shell without destroying the
                    // branch's retained scroll position or loaded pages.
                    onTap: () =>
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute<void>(
                            builder: (_) => FanartDetailPage(item: item),
                          ),
                        ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: FeedStatusFooter(
                status: state.status,
                failure: state.failure,
                onRetry: onRetryAppend,
                onRefresh: onRefresh,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FeedEmpty extends StatelessWidget {
  const _FeedEmpty();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          const Text('没有符合条件的内容'),
        ],
      ),
    ),
  );
}

class _FeedError extends StatelessWidget {
  const _FeedError({required this.failure, required this.onRetry});

  final ApiFailure? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
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
    ),
  );
}
