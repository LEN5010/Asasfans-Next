import 'dart:async';
import 'dart:math' as math;

import '../../../core/domain/content_identity.dart';
import '../../handoff/application/handoff_providers.dart';
import '../../handoff/domain/return_context.dart';
import '../../handoff/presentation/anchor_restore.dart';
import 'content_search_control.dart';
import 'saved_channel_bar.dart';
import '../domain/saved_channel.dart';
import '../../rules/application/feed_visibility.dart';
import '../../rules/presentation/rule_filter_scope.dart';

import 'package:flutter/material.dart';

import '../../../shared/widgets/feed_offset_memory.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/auto_fill_viewport.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../../shared/widgets/query_summary.dart';
import '../../../shared/widgets/feed_scroll_view.dart';
import '../../../shared/widgets/app_panel.dart';
import '../../../shared/widgets/app_controls.dart';
import 'content_images.dart';
import 'dynamic_card.dart';
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

class _DynamicFeedViewState extends ConsumerState<DynamicFeedView>
    with FeedOffsetMemory {
  @override
  String get offsetStorageId => 'feed-offset-dynamics';

  ScrollController get _scrollController => feedScrollController();
  late final DynamicFeedController _controller = ref.read(
    dynamicFeedControllerProvider,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.loadInitial();
      unawaited(_restoreReturn());
    });
  }

  /// Identities in display order, as last built.
  List<ContentIdentity> _visible = const [];

  Future<void> _restoreReturn() async {
    final pending = await ref
        .read(handoffCoordinatorProvider)
        .listRestoreFor(ContentChannel.dynamics.slug);
    if (!mounted || pending == null) return;
    if (pending.query case final values?) {
      await _controller.applyQuery(
        ChannelSpec(
          version: ChannelSpec.currentVersion,
          values: values,
        ).toDynamic(),
      );
    }
    final anchor = pending.anchor;
    if (anchor == null || !mounted) return;
    await waitForFirstPage(
      _controller,
      () =>
          _controller.state.status == FeedStatus.idle ||
          _controller.state.status == FeedStatus.loadingFirstPage,
    );
    // _visible is refreshed by the build that follows a change, not by it.
    await WidgetsBinding.instance.endOfFrame;
    for (var page = 0; page < restorePageBudget; page++) {
      // The viewport may be filling itself; let that page land first.
      await waitForFirstPage(
        _controller,
        () => _controller.state.status == FeedStatus.appending,
      );
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted ||
          _visible.contains(anchor.identity) ||
          _controller.state.status != FeedStatus.ready) {
        break;
      }
      await _controller.loadMore();
    }
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    // The return decides the position now, not a remembered offset.
    cancelOffsetSettle();
    final result = await restoreAnchor(
      scope: context,
      controller: _scrollController,
      anchor: anchor,
      order: _visible,
    );
    if (result == AnchorRestore.offsetOnly && mounted) {
      showAnchorFallbackNotice(context);
    }
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
      // The controls sit over the reading column they filter.
      final filters = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppTokens.readingWidth + 32,
          ),
          child: _DynamicFilterBar(query: state.query, onChanged: _applyQuery),
        ),
      );
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
          child: _buildBody(
            state.copyWith(items: visible.items),
            visible.userHidden.length,
            [filters, RuleStatusBar(visibility: visible)],
          ),
        ),
      );
    },
  );

  Widget _buildBody(DynamicFeedState state, int hidden, List<Widget> header) {
    _visible = [for (final post in state.items) post.identity];
    final returnQuery = ChannelSpec.ofDynamic(state.query).values;
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
            FeedStatus.endOfList || FeedStatus.stalled when hidden > 0 =>
              FeedAllHiddenMessage(count: hidden),
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
        // One reading column: a comfortable line length on wide windows
        // rather than a wall of cards.
        SliverLayoutBuilder(
          builder: (context, constraints) => SliverPadding(
            padding: EdgeInsets.fromLTRB(
              math.max(
                16,
                (constraints.crossAxisExtent - AppTokens.readingWidth) / 2,
              ),
              0,
              math.max(
                16,
                (constraints.crossAxisExtent - AppTokens.readingWidth) / 2,
              ),
              0,
            ),
            sliver: SliverList.separated(
              itemCount: state.items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) => DynamicCard(
                key: ValueKey(state.items[index].identity),
                post: state.items[index],
                returnQuery: returnQuery,
                anchorOf: () => ReturnAnchor(
                  identity: state.items[index].identity,
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
  }
}

class _DynamicFilterBar extends ConsumerStatefulWidget {
  const _DynamicFilterBar({required this.query, required this.onChanged});
  final DynamicQuery query;
  final ValueChanged<DynamicQuery> onChanged;
  @override
  ConsumerState<_DynamicFilterBar> createState() => _DynamicFilterBarState();
}

class _DynamicFilterBarState extends ConsumerState<_DynamicFilterBar> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final query = widget.query;
    final members =
        ref.watch(dynamicMembersProvider).valueOrNull ??
        const <DynamicMember>[];
    final member = members
        .where((member) => member.id == query.memberId)
        .firstOrNull;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        void apply(DynamicQuery next) {
          setState(() => _expanded = false);
          widget.onChanged(next);
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
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
                          value: query.keyword,
                          hint: '搜索历史动态',
                          expanded: true,
                          onSubmitted: (keyword) =>
                              apply(query.copyWith(keyword: keyword)),
                          filter: AppButton.icon(
                            tooltip: '筛选与排序',
                            selected:
                                _expanded || query != const DynamicQuery(),
                            icon: const Icon(Icons.tune),
                            onPressed: () async {
                              if (wide) {
                                setState(() => _expanded = !_expanded);
                                return;
                              }
                              final next = await showAppPanel<DynamicQuery>(
                                context: context,
                                builder: (context) => _DynamicFilterPanel(
                                  query: query,
                                  onApply: (next) =>
                                      Navigator.pop(context, next),
                                  onClose: () => Navigator.pop(context),
                                ),
                              );
                              if (next != null && mounted) apply(next);
                            },
                          ),
                        ),
                      ),
                      MenuAnchor(
                        menuChildren: [
                          SavedChannelBar(
                            menuItem: true,
                            feed: ChannelFeed.dynamic,
                            currentSpec: () => ChannelSpec.ofDynamic(query),
                            onOpen: (spec) => apply(spec.toDynamic()),
                          ),
                          MenuItemButton(
                            onPressed:
                                ref
                                    .read(dynamicFeedControllerProvider)
                                    .state
                                    .isBusy
                                ? null
                                : ref
                                      .read(dynamicFeedControllerProvider)
                                      .refresh,
                            leadingIcon: const Icon(Icons.refresh),
                            child: const Text('刷新'),
                          ),
                        ],
                        builder: (context, menu, _) => AppButton.icon(
                          tooltip: '更多内容操作',
                          filled: true,
                          onPressed: () =>
                              menu.isOpen ? menu.close() : menu.open(),
                          icon: const Icon(Icons.more_horiz),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              QuerySummary(
                padding: const EdgeInsets.only(top: 2),
                clearTooltip: '清除筛选',
                onClear: () => apply(const DynamicQuery()),
                applied: [
                  if (query.keyword.isNotEmpty)
                    (
                      label: '“${query.keyword}”',
                      remove: () => apply(query.copyWith(keyword: '')),
                    ),
                  if (query.memberId != null)
                    (
                      label: member?.name ?? '指定成员',
                      remove: () => apply(query.copyWith(clearMember: true)),
                    ),
                  if (query.type != null)
                    (
                      label: dynamicTypeLabel(query.type!),
                      remove: () => apply(query.copyWith(clearType: true)),
                    ),
                  if (query.from != null || query.to != null)
                    (
                      label: _rangeLabel(query.from, query.to),
                      remove: () => apply(query.copyWith(clearRange: true)),
                    ),
                  if (query.sort != DynamicSort.newest)
                    (
                      label: _sortLabel(query.sort),
                      remove: () =>
                          apply(query.copyWith(sort: DynamicSort.newest)),
                    ),
                ],
              ),
              // The inline panel grows open and folds away instead of jumping.
              AnimatedSize(
                duration: appMotion(context, AppTokens.controlMotion),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: !(wide && _expanded)
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Card(
                          child: _DynamicFilterPanel(
                            key: ValueKey(query),
                            query: query,
                            embedded: true,
                            onApply: apply,
                            onClose: () => setState(() => _expanded = false),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A date range in words. The picker stores calendar dates and the server's
/// `to` is exclusive, so the last day shown is the one before it.
String _rangeLabel(DateTime? from, DateTime? to) {
  String day(DateTime value) => '${value.month}月${value.day}日';
  final last = to?.subtract(const Duration(days: 1));
  return switch ((from, last)) {
    (final from?, final last?) when day(from) == day(last) => day(from),
    (final from?, final last?) => '${day(from)}–${day(last)}',
    (final from?, null) => '${day(from)} 起',
    (null, final last?) => '至 ${day(last)}',
    _ => '已选日期',
  };
}

String _sortLabel(DynamicSort sort) => switch (sort) {
  DynamicSort.newest => '最新发布',
  DynamicSort.oldest => '最早发布',
  DynamicSort.likes => '点赞最多',
  DynamicSort.comments => '评论最多',
};

class _DynamicFilterPanel extends ConsumerStatefulWidget {
  const _DynamicFilterPanel({
    super.key,
    required this.query,
    required this.onApply,
    required this.onClose,
    this.embedded = false,
  });
  final DynamicQuery query;
  final ValueChanged<DynamicQuery> onApply;
  final VoidCallback onClose;
  final bool embedded;
  @override
  ConsumerState<_DynamicFilterPanel> createState() =>
      _DynamicFilterPanelState();
}

class _DynamicFilterPanelState extends ConsumerState<_DynamicFilterPanel> {
  late DynamicQuery _draft = widget.query;
  // A chosen extra member keeps the section open; the notice was accepted.
  late bool _moreOpen =
      _draft.memberId != null && !_primaryIds.contains(_draft.memberId);

  /// Accepted once per launch, so reopening the panel does not ask again.
  static bool _moreAccepted = false;

  Future<void> _toggleMore() async {
    if (!_moreOpen && !_moreAccepted) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.info_outline),
          title: const Text('查看更多成员'),
          content: const Text(
            '以下账号不属于 A-SOUL 现役成员，相关动态仅作为公开内容的存档展示，'
            '部分内容可能引起不适，请谨慎查看。\n\n'
            '免责声明：Asasfans Next 是非官方粉丝项目，与 A-SOUL 及相关公司无关。'
            '动态版权归原作者所有，展示不代表本应用立场；'
            '如有不当内容，请通过 GitHub Issues 反馈处理。',
          ),
          actions: [
            AppButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            AppButton(
              selected: true,
              onPressed: () => Navigator.pop(context, true),
              child: const Text('我已了解，继续'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
      _moreAccepted = true;
    }
    setState(() => _moreOpen = !_moreOpen);
  }

  static const _primaryIds = [
    'uid:672328094',
    'uid:672353429',
    'uid:672342685',
    'uid:3537115310721181',
    'uid:3537115310721781',
    'uid:703007996',
  ];

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _draft.from != null && _draft.to != null
          ? DateTimeRange(
              start: _draft.from!,
              end: _draft.to!.subtract(const Duration(milliseconds: 1)),
            )
          : null,
    );
    if (picked == null || !mounted) return;
    // The server's `to` is exclusive and serialized as a date. Preserve the
    // selected last day, including when the user chooses just one day.
    setState(
      () => _draft = _draft.copyWith(
        from: picked.start,
        to: DateTime(picked.end.year, picked.end.month, picked.end.day + 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final members = ref.watch(dynamicMembersProvider);
    final roster = members.valueOrNull ?? const <DynamicMember>[];
    final primary = [
      for (final id in _primaryIds)
        ...roster.where((member) => member.id == id),
    ];
    final other = roster.where((member) => !_primaryIds.contains(member.id));
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Text(text, style: theme.textTheme.titleSmall),
    );
    Widget memberButton(DynamicMember member) => AppButton(
      tooltip: member.name,
      selected: _draft.memberId == member.id,
      onPressed: () =>
          setState(() => _draft = _draft.copyWith(memberId: member.id)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ContentAvatar(name: member.name, image: member.avatarUrl, size: 28),
          const SizedBox(width: 8),
          Text(member.name),
        ],
      ),
    );
    final fields = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading('成员'),
          if (members.isLoading) const LinearProgressIndicator(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppButton(
                selected: _draft.memberId == null,
                onPressed: () =>
                    setState(() => _draft = _draft.copyWith(clearMember: true)),
                child: const Text('全部成员'),
              ),
              for (final member in primary) memberButton(member),
            ],
          ),
          if (members.hasError)
            Row(
              children: [
                const Expanded(child: Text('成员暂时加载失败')),
                AppButton(
                  onPressed: () => ref.invalidate(dynamicMembersProvider),
                  child: const Text('重试'),
                ),
              ],
            ),
          if (other.isNotEmpty) ...[
            const SizedBox(height: 12),
            AppButton(
              onPressed: _toggleMore,
              child: Row(
                children: [
                  const Expanded(child: Text('更多成员')),
                  AnimatedRotation(
                    turns: _moreOpen ? .5 : 0,
                    duration: appMotion(context, AppTokens.controlMotion),
                    child: const Icon(Icons.expand_more),
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: appMotion(context, AppTokens.controlMotion),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !_moreOpen
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final member in other) memberButton(member),
                        ],
                      ),
                    ),
            ),
          ],
          heading('动态类型'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppButton(
                selected: _draft.type == null,
                onPressed: () =>
                    setState(() => _draft = _draft.copyWith(clearType: true)),
                child: const Text('全部'),
              ),
              for (final type in DynamicType.values)
                AppButton(
                  selected: _draft.type == type,
                  onPressed: () =>
                      setState(() => _draft = _draft.copyWith(type: type)),
                  child: Text(dynamicTypeLabel(type)),
                ),
            ],
          ),
          heading('发布日期'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppButton(
                onPressed: _pickRange,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.date_range_outlined),
                    SizedBox(width: 8),
                    Text('选择日期'),
                  ],
                ),
              ),
              if (_draft.from != null && _draft.to != null)
                Text(
                  '${_day(_draft.from!)} — ${_day(_draft.to!.subtract(const Duration(milliseconds: 1)))}',
                ),
              if (_draft.from != null || _draft.to != null)
                AppButton.icon(
                  tooltip: '清除日期',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(
                    () => _draft = _draft.copyWith(clearRange: true),
                  ),
                ),
            ],
          ),
          heading('排序'),
          AppSegments<DynamicSort>(
            values: DynamicSort.values,
            labelOf: _sortLabel,
            selected: _draft.sort,
            onChanged: (sort) =>
                setState(() => _draft = _draft.copyWith(sort: sort)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
    return Column(
      mainAxisSize: widget.embedded ? MainAxisSize.min : MainAxisSize.max,
      children: [
        AppPanelHeader(
          title: '筛选动态',
          onClose: widget.onClose,
          actions: [
            AppButton(
              onPressed: () => setState(() => _draft = const DynamicQuery()),
              child: const Text('重置'),
            ),
          ],
        ),
        if (widget.embedded)
          fields
        else
          Expanded(child: SingleChildScrollView(child: fields)),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                AppButton(onPressed: widget.onClose, child: const Text('取消')),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    selected: true,
                    onPressed: () => widget.onApply(_draft),
                    child: const Text('应用筛选'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _day(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
