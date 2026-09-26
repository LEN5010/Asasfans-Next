import 'dart:async';

import '../../rules/application/rules_providers.dart';
import '../../rules/application/visible_random.dart';
import '../../rules/presentation/rule_common.dart';
import '../../novels/presentation/novel_feed_view.dart';
import '../../rules/application/feed_visibility.dart';
import '../../rules/presentation/rule_filter_scope.dart';

import 'package:flutter/material.dart';

import '../../../shared/widgets/feed_offset_memory.dart';

import '../../../shared/widgets/app_page_bar.dart';
import '../../../shared/widgets/app_controls.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_failure.dart';
import '../../../shared/widgets/auto_fill_viewport.dart';
import '../../../shared/widgets/feed_scroll_view.dart';
import '../../handoff/application/handoff_providers.dart';
import '../../handoff/application/handoff_coordinator.dart';
import '../../handoff/domain/return_context.dart';
import '../../handoff/presentation/anchor_restore.dart';
import '../../../core/domain/content_identity.dart';
import '../application/content_providers.dart';
import '../application/fanart_feed_controller.dart';
import '../domain/community_video_repository.dart';
import '../domain/fanart_repository.dart';
import 'channel_tabs.dart';
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

class ContentPage extends ConsumerStatefulWidget {
  const ContentPage({this.channel = 'videos', this.videoKind, super.key});
  final String channel;

  /// The video filter to open with, from a return or an old channel link.
  final String? videoKind;

  @override
  ConsumerState<ContentPage> createState() => _ContentPageState();
}

/// Channels are one page: switching slides the feed inside the page.
///
/// Only the current and the most recently left channel stay mounted, so one
/// can slide out while the other slides in and a quick switch back is free.
/// Older channels are unmounted: their offstage cards would otherwise keep
/// every decoded image alive. What the user built up survives elsewhere —
/// the query and loaded pages in the channel's kept-alive controller, the
/// scroll offset in PageStorage.
class _ContentPageState extends ConsumerState<ContentPage>
    with SingleTickerProviderStateMixin {
  late ContentChannel _current = _parse(widget.channel);
  late CommunityChannel _kind = _parseKind(widget.videoKind);
  ContentChannel? _previous;

  /// Mounted channels, least recently shown first.
  late final _mounted = <ContentChannel>[_current];
  static const _mountedLimit = 2;
  late final _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );

  static ContentChannel _parse(String slug) =>
      ContentChannel.fromSlug(slug) ?? ContentChannel.videos;

  static CommunityChannel _parseKind(String? name) =>
      CommunityChannel.values.where((c) => c.name == name).firstOrNull ??
      CommunityChannel.latest;

  late final HandoffCoordinator _handoff = ref.read(handoffCoordinatorProvider);

  @override
  void initState() {
    super.initState();
    _handoff.addListener(_onHandoff);
  }

  /// 继续挑选 into a video kind: the kind lives in page state, not only in
  /// the route, so a route that did not change must still switch to it.
  void _onHandoff() {
    final kind = CommunityChannel.values
        .where((value) => _handoff.hasBrowseRestoreFor(value.name))
        .firstOrNull;
    if (kind != null && kind != _kind && mounted) {
      setState(() => _kind = kind);
    }
  }

  @override
  void didUpdateWidget(ContentPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.videoKind != null && widget.videoKind != oldWidget.videoKind) {
      setState(() => _kind = _parseKind(widget.videoKind));
    }
    final next = _parse(widget.channel);
    if (next == _current) return;
    setState(() {
      _previous = _current;
      _current = next;
      _mounted
        ..remove(next)
        ..add(next);
      while (_mounted.length > _mountedLimit) {
        _mounted.removeAt(0);
      }
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      _slide.value = 1;
    } else {
      _slide.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _handoff.removeListener(_onHandoff);
    _slide.dispose();
    super.dispose();
  }

  Widget _feed(ContentChannel channel) => switch (channel) {
    ContentChannel.videos => CommunityFeedView(
      key: ValueKey(_kind),
      channel: _kind,
      onChannel: (kind) => setState(() => _kind = kind),
    ),
    ContentChannel.fanart => _FanartFeed(channel: channel),
    ContentChannel.dynamics => const DynamicFeedView(),
    ContentChannel.novels => const NovelFeedView(),
  };

  // One stable structure per channel, so moving between active, leaving and
  // offstage never remounts the feed.
  Widget _entry(ContentChannel channel, Widget feed) {
    final active = channel == _current;
    final leaving = channel == _previous && _slide.isAnimating;
    final direction = _previous == null || _current.index >= _previous!.index
        ? 1.0
        : -1.0;
    final curve = _slide.drive(CurveTween(curve: Curves.easeOutCubic));
    final Animation<Offset> position = active
        ? Tween(begin: Offset(direction, 0), end: Offset.zero).animate(curve)
        : leaving
        ? Tween(begin: Offset.zero, end: Offset(-direction, 0)).animate(curve)
        : const AlwaysStoppedAnimation(Offset.zero);
    return KeyedSubtree(
      key: ValueKey(channel),
      child: Offstage(
        offstage: !active && !leaving,
        child: TickerMode(
          enabled: active || leaving,
          child: SlideTransition(position: position, child: feed),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Stable order, so a switch reorders nothing that stays mounted.
    final feeds = {
      for (final channel in ContentChannel.values)
        if (_mounted.contains(channel)) channel: _feed(channel),
    };
    return Scaffold(
      extendBodyBehindAppBar: true,
      // The shell's backdrop shows through the main pages.
      backgroundColor: Colors.transparent,
      appBar: AppPageBar(
        // A new channel starts with its controls visible.
        revealKey: _current,
        titleIsControl: true,
        controlExtent: ChannelTabs.heightFor(MediaQuery.textScalerOf(context)),
        title: _ChannelStrip(current: _current),
      ),
      body: ClipRect(
        child: AnimatedBuilder(
          animation: _slide,
          builder: (context, _) => Stack(
            fit: StackFit.expand,
            children: [
              for (final entry in feeds.entries) _entry(entry.key, entry.value),
            ],
          ),
        ),
      ),
    );
  }
}

/// The channels, as the page's title: text tabs, not another filter row.
class _ChannelStrip extends StatelessWidget {
  const _ChannelStrip({required this.current});
  final ContentChannel current;
  @override
  Widget build(BuildContext context) => ChannelTabs<ContentChannel>(
    values: ContentChannel.values,
    labelOf: (value) => value.label,
    selected: current,
    onChanged: (value) => context.go('/content/${value.slug}'),
  );
}

/// Draws one random post and opens it directly.
///
/// Each draw is an independent request, so the button disables itself while
/// one is in flight instead of letting repeated taps stack up requests.
class _FanartMoreActions extends ConsumerStatefulWidget {
  const _FanartMoreActions({required this.channel});
  final ContentChannel channel;

  @override
  ConsumerState<_FanartMoreActions> createState() => _FanartMoreActionsState();
}

class _FanartMoreActionsState extends ConsumerState<_FanartMoreActions> {
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
      openFanart(
        context,
        ref,
        item,
        returnTo: ReturnTarget.contentChannel,
        channel: ContentChannel.fanart.slug,
        query: ChannelSpec.ofFanart(query).values,
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
  Widget build(BuildContext context) {
    final feed = ref.read(fanartFeedControllerProvider(widget.channel));
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          onPressed: _loading ? null : _draw,
          leadingIcon: const Icon(Icons.shuffle),
          child: const Text('随机二创'),
        ),
        SavedChannelBar(
          menuItem: true,
          feed: ChannelFeed.fanart,
          currentSpec: () => ChannelSpec.ofFanart(feed.state.query),
          onOpen: (spec) => feed.applyQuery(spec.toFanart()),
        ),
        MenuItemButton(
          onPressed: feed.state.isBusy ? null : feed.refresh,
          leadingIcon: const Icon(Icons.refresh),
          child: const Text('刷新'),
        ),
      ],
      builder: (context, menu, _) => AppButton.icon(
        tooltip: '更多内容操作',
        filled: true,
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
        icon: _loading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.more_horiz),
      ),
    );
  }
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

class _FanartFeedState extends ConsumerState<_FanartFeed>
    with FeedOffsetMemory {
  @override
  String get offsetStorageId => 'feed-offset-fanart-${widget.channel.slug}';

  ScrollController get _scrollController => feedScrollController();
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
    _handoff.addListener(_onHandoff);
  }

  late final HandoffCoordinator _handoff = ref.read(handoffCoordinatorProvider);

  /// A 继续挑选 aimed at this feed while it is already built.
  void _onHandoff() {
    if (mounted && _handoff.hasBrowseRestoreFor(widget.channel.slug)) {
      unawaited(_restoreReturn());
    }
  }

  @override
  void dispose() {
    _handoff.removeListener(_onHandoff);
    super.dispose();
  }

  /// Re-applies the query and position a return session stored for this channel.
  ///
  /// The session is read, not consumed: the restorer owns consumption, and
  /// claiming it here would race the navigation that brought us to this channel.
  Future<void> _restoreReturn() async {
    final pending = await ref
        .read(handoffCoordinatorProvider)
        .listRestoreFor(widget.channel.slug);
    if (!mounted || pending == null) return;
    // One restore at a time, and only while the user has not moved on: a
    // newer restore, or a query or refresh of their own, ends this one.
    final serial = ++_restoreSerial;
    var generation = _controller.generation;
    bool current() =>
        mounted &&
        serial == _restoreSerial &&
        _controller.generation == generation;
    final values = pending.query;
    if (values != null) {
      // A cold return arrives with the channel chosen but the filters at their
      // defaults, so re-apply what the user had actually committed.
      final applying = _controller.applyQuery(
        ChannelSpec(
          version: ChannelSpec.currentVersion,
          values: values,
        ).toFanart(),
      );
      generation = _controller.generation;
      await applying;
    }
    final anchor = pending.anchor;
    if (anchor == null || !current()) return;
    await waitForFirstPage(
      _controller,
      () =>
          _controller.state.status == FeedStatus.idle ||
          _controller.state.status == FeedStatus.loadingFirstPage,
    );
    // _visible is refreshed by the build that follows a change, not by it.
    await WidgetsBinding.instance.endOfFrame;
    // Only a bounded restore: a few more pages at most, never page after
    // page to reach a deep position.
    for (var page = 0; page < restorePageBudget; page++) {
      // The viewport may be filling itself; let that page land first.
      await waitForFirstPage(
        _controller,
        () => _controller.state.status == FeedStatus.appending,
      );
      await WidgetsBinding.instance.endOfFrame;
      if (!current()) return;
      if (_visible.contains(anchor.identity) ||
          _controller.state.status != FeedStatus.ready ||
          _controller.state.nextCursor == null) {
        break;
      }
      await _controller.loadMore();
    }
    await WidgetsBinding.instance.endOfFrame;
    // Restore against the restored list's layout, not the loading
    // placeholder's zero scroll extent.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !current()) return;
    // The return decides the position now, not a remembered offset.
    cancelOffsetSettle();
    final result = await restoreAnchor(
      scope: context,
      controller: _scrollController,
      anchor: anchor,
      order: _visible,
    );
    if (result == AnchorRestore.offsetOnly && mounted) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('原位置已不在列表中，已回到相近位置')));
    }
  }

  /// Bumped by each restore that starts; an older one then stops.
  var _restoreSerial = 0;

  /// Identities in display order, as last built (rules may hide or reorder).
  List<ContentIdentity> _visible = const [];

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
      // Search sits at the head of the feed, as in dynamics and novels.
      final filters = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: ContentSearchControl.rowWidth,
                ),
                child: Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: ContentSearchControl(
                        value: state.query.keyword,
                        hint: '搜索二创正文或作者',
                        expanded: true,
                        onSubmitted: (keyword) =>
                            _applyQuery(state.query.copyWith(keyword: keyword)),
                        filter: FanartFilterButton(
                          query: state.query,
                          onChanged: _applyQuery,
                        ),
                      ),
                    ),
                    _FanartMoreActions(channel: widget.channel),
                  ],
                ),
              ),
            ),
          ),
          FanartQuickFilters(query: state.query, onChanged: _applyQuery),
          FanartFilterBar(query: state.query, onChanged: _applyQuery),
        ],
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
            hidden: visible.userHidden.length,
            onBuilt: (items) =>
                _visible = [for (final item in items) item.identity],
            state: state.copyWith(items: visible.items),
            header: [
              filters,
              if (state.status == FeedStatus.failed && visible.items.isNotEmpty)
                FeedStaleNotice(
                  failure: state.failure,
                  onRetry: _controller.refresh,
                ),
              RuleStatusBar(visibility: visible),
            ],
            controller: _scrollController,
            onRetryAppend: _controller.loadMore,
            onRefresh: _controller.refresh,
            onClear: () => _applyQuery(const FanartQuery()),
          ),
        ),
      );
    },
  );
}

class _FanartGrid extends ConsumerWidget {
  const _FanartGrid({
    required this.hidden,
    required this.onBuilt,
    required this.state,
    required this.header,
    required this.controller,
    required this.onRetryAppend,
    required this.onRefresh,
    required this.onClear,
  });

  final ValueChanged<List<FanartItem>> onBuilt;

  /// Back to the channel's defaults, from the empty state.
  final VoidCallback onClear;

  /// Loaded items the user's rules hide.
  final int hidden;
  final FanartFeedState state;
  final List<Widget> header;
  final ScrollController controller;
  final VoidCallback onRetryAppend;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    onBuilt(state.items);
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
            FeedStatus.endOfList || FeedStatus.stalled when hidden > 0 =>
              FeedAllHiddenMessage(count: hidden),
            FeedStatus.endOfList => FeedMessage.empty(
              noun: '二创',
              filtered: state.query != const FanartQuery(),
              // Unlike the summary's 清除条件, this also clears the members:
              // the label says so.
              clearLabel: '清除全部条件',
              onClear: onClear,
              onRefresh: onRefresh,
            ),
            _ => null,
          };
    return FeedScrollView(
      storageKey: const PageStorageKey('fanart-feed'),
      controller: controller,
      onRefresh: onRefresh,
      header: header,
      placeholder: placeholder,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              if (state.items.isEmpty) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              final width = constraints.crossAxisExtent;
              final scaler = MediaQuery.textScalerOf(context);
              final gap = width >= 760 ? 16.0 : 12.0;
              // One stable extent per width: tiles share the portrait box
              // and caption lines, so the grid never shifts as art loads.
              final minimum =
                  (width >= 760 ? 200.0 : 136.0) *
                  scaler.scale(1).clamp(1.0, 1.6);
              final columns = ((width + gap) / (minimum + gap)).floor().clamp(
                1,
                6,
              );
              final cell = (width - gap * (columns - 1)) / columns;
              return SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: gap,
                  mainAxisSpacing: gap + 4,
                  mainAxisExtent: FanartCard.extentFor(
                    state.items.first,
                    cell,
                    scaler,
                  ),
                ),
                itemCount: state.items.length,
                itemBuilder: (context, index) {
                  final item = state.items[index];
                  return FanartCard(
                    key: ValueKey(item.identity),
                    item: item,
                    heroTag: fanartHeroTag(item),
                    onLongPress: () => showContentActions(
                      context,
                      ContentSnapshots.fanart(item),
                      ruleSubject: RuleSubjects.fanart(item),
                    ),
                    // A root route or an external open keeps the branch's
                    // scroll position and loaded pages.
                    onTap: () => openFanart(
                      context,
                      ref,
                      item,
                      returnTo: ReturnTarget.contentChannel,
                      channel: ContentChannel.fanart.slug,
                      query: ChannelSpec.ofFanart(state.query).values,
                      anchor: ReturnAnchor(
                        identity: item.identity,
                        offset: controller.offset,
                      ),
                      heroTag: fanartHeroTag(item),
                    ),
                  );
                },
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
  }
}
