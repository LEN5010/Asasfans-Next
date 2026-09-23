import 'dart:async';

import '../../rules/application/rules_providers.dart';
import '../../rules/application/visible_random.dart';
import '../../rules/presentation/rule_common.dart';
import '../../subscriptions/presentation/subscription_feed_view.dart';
import '../../subscriptions/application/subscription_providers.dart';
import '../../library/presentation/library_pages.dart' show SubscriptionsPage;
import '../../rules/application/feed_visibility.dart';
import '../../rules/presentation/rule_filter_scope.dart';

import 'package:flutter/material.dart';

import '../../../shared/widgets/app_page_bar.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_failure.dart';
import '../../../shared/widgets/auto_fill_viewport.dart';
import '../../../shared/widgets/feed_scroll_view.dart';
import '../../../shared/widgets/media_grid_delegate.dart';
import '../../handoff/application/handoff_providers.dart';
import '../../handoff/domain/return_context.dart';
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
    return LayoutBuilder(
      builder: (context, constraints) => Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppPageBar(
          title: _ChannelStrip(current: current),
          actions: [_headerActions(ref, current, constraints.maxWidth >= 1040)],
        ),
        body: switch (current) {
          ContentChannel.subscriptions => const SubscriptionFeedView(),
          ContentChannel.fanart => _FanartFeed(channel: current),
          ContentChannel.dynamics => const DynamicFeedView(),
          _ => CommunityFeedView(
            key: ValueKey(current),
            channel: current.communityChannel!,
          ),
        },
      ),
    );
  }

  Widget _headerActions(WidgetRef ref, ContentChannel channel, bool wide) {
    if (channel == ContentChannel.subscriptions) {
      final controller = ref.watch(subscriptionFeedControllerProvider);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Builder(
            builder: (context) => IconButton(
              tooltip: '管理订阅',
              onPressed: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SubscriptionsPage(),
                ),
              ),
              icon: const Icon(Icons.people_outline),
            ),
          ),
          IconButton(
            tooltip: '刷新订阅更新',
            onPressed: controller.loading ? null : controller.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      );
    }
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
            SavedChannelBar(
              feed: ChannelFeed.fanart,
              currentSpec: () => ChannelSpec.ofFanart(controller.state.query),
              onOpen: (spec) => controller.applyQuery(spec.toFanart()),
            ),
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
            SavedChannelBar(
              feed: ChannelFeed.dynamic,
              currentSpec: () => ChannelSpec.ofDynamic(controller.state.query),
              onOpen: (spec) => controller.applyQuery(spec.toDynamic()),
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

/// Channel tabs inside the page bar's title pill.
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      key: const PageStorageKey('content-channel-strip'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final value in ContentChannel.values)
            Semantics(
              selected: widget.current == value,
              child: TextButton(
                key: widget.current == value ? _selected : ValueKey(value),
                onPressed: () => context.go('/content/${value.slug}'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: const StadiumBorder(),
                  backgroundColor: widget.current == value
                      ? colors.primaryContainer
                      : null,
                  foregroundColor: widget.current == value
                      ? colors.primary
                      : colors.onSurface,
                  textStyle: TextStyle(
                    fontSize: 14,
                    fontWeight: widget.current == value
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
                child: Text(value.label),
              ),
            ),
        ],
      ),
    );
  }
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
      if (!mounted) return;
      // Load first and restore after. Waiting on storage before the first fetch
      // would let a slow or unavailable store delay ordinary browsing, and the
      // common case has no return session at all.
      _controller.loadInitial();
      unawaited(_restoreReturn());
    });
  }

  /// Re-applies the query and position a return session stored for this channel.
  ///
  /// The session is read, not consumed: the restorer owns consumption, and
  /// claiming it here would race the navigation that brought us to this channel.
  Future<void> _restoreReturn() async {
    final pending = await ref.read(handoffCoordinatorProvider).lastReturn();
    if (!mounted ||
        pending == null ||
        pending.target != ReturnTarget.contentChannel ||
        pending.channel != widget.channel.slug) {
      return;
    }
    final values = pending.query;
    if (values != null) {
      // A cold return arrives with the channel chosen but the filters at their
      // defaults, so re-apply what the user had actually committed.
      await _controller.applyQuery(
        ChannelSpec(
          version: ChannelSpec.currentVersion,
          values: values,
        ).toFanart(),
      );
    }
    if (!mounted) return;
    _restoreAnchor(pending.anchor);
  }

  /// Returns to where the user was, preferring the identity over the raw offset:
  /// an offset alone points at whatever has since moved into that position.
  ///
  /// Only a bounded restore is attempted. If the anchored item is not in what
  /// has loaded, the stored offset is used and clamped to the current extent —
  /// the app does not fetch page after page to reach a deep position.
  void _restoreAnchor(ReturnAnchor? anchor) {
    if (anchor == null || !_scrollController.hasClients) return;
    final found = _controller.state.items.any(
      (item) => item.identity == anchor.identity,
    );
    final offset = anchor.offset;
    if (found || offset == null) return;
    _scrollController.jumpTo(
      offset.clamp(0, _scrollController.position.maxScrollExtent),
    );
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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final state = _controller.state;
      final filters = FanartFilterBar(
        query: state.query,
        onChanged: _applyQuery,
      );
      return RuleFilterScope(
        items: state.items,
        subjectOf: RuleSubjects.fanart,
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
          child: _FanartGrid(
            state: state.copyWith(items: visible.items),
            header: [
              filters,
              RuleStatusBar(visibility: visible),
            ],
            controller: _scrollController,
            onRetryAppend: _controller.loadMore,
            onRefresh: _controller.refresh,
          ),
        ),
      );
    },
  );
}

class _FanartGrid extends StatelessWidget {
  const _FanartGrid({
    required this.state,
    required this.header,
    required this.controller,
    required this.onRetryAppend,
    required this.onRefresh,
  });

  final FanartFeedState state;
  final List<Widget> header;
  final ScrollController controller;
  final VoidCallback onRetryAppend;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final placeholder = state.items.isNotEmpty
        ? null
        : switch (state.status) {
            FeedStatus.failed => FeedMessage(
              icon: Icons.cloud_off_outlined,
              text: state.failure?.message ?? '内容加载失败',
              failure: state.failure,
              onRetry: onRefresh,
            ),
            FeedStatus.idle || FeedStatus.loadingFirstPage => const Center(
              child: CircularProgressIndicator(),
            ),
            FeedStatus.endOfList => const FeedMessage(
              icon: Icons.search_off_outlined,
              text: '没有符合条件的内容',
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
          storageKey: const PageStorageKey('fanart-feed'),
          controller: controller,
          onRefresh: onRefresh,
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
