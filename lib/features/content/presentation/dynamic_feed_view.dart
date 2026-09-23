import '../../rules/application/feed_visibility.dart';
import '../../rules/presentation/rule_filter_scope.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/auto_fill_viewport.dart';
import '../../../shared/widgets/feed_scroll_view.dart';
import '../../../shared/widgets/app_panel.dart';
import '../../../shared/widgets/glass/app_glass_controls.dart';
import '../../../shared/widgets/sliver_content_masonry.dart';
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
      final filters = _DynamicFilterBar(
        query: state.query,
        onChanged: _applyQuery,
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
          sliver: SliverContentMasonry(
            itemCount: state.items.length,
            itemBuilder: (context, index) => DynamicCard(
              key: ValueKey(state.items[index].identity),
              post: state.items[index],
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
    final summary = [
      if (query.keyword.isNotEmpty) '“${query.keyword}”',
      if (query.memberId != null) member?.name ?? '指定成员',
      if (query.type != null) dynamicTypeLabel(query.type!),
      if (query.from != null || query.to != null) '已选日期',
      _sortLabel(query.sort),
    ].join(' · ');
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
              Row(
                children: [
                  AppGlassButton(
                    selected: _expanded || query != const DynamicQuery(),
                    onPressed: () async {
                      if (wide) {
                        setState(() => _expanded = !_expanded);
                        return;
                      }
                      final next = await showAppPanel<DynamicQuery>(
                        context: context,
                        builder: (context) => _DynamicFilterPanel(
                          query: query,
                          onApply: (next) => Navigator.pop(context, next),
                          onClose: () => Navigator.pop(context),
                        ),
                      );
                      if (next != null && mounted) apply(next);
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tune),
                        SizedBox(width: 8),
                        Text('筛选与排序'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (query != const DynamicQuery())
                    AppGlassButton.icon(
                      tooltip: '清除筛选',
                      onPressed: () => apply(const DynamicQuery()),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
              if (wide && _expanded)
                Padding(
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
            ],
          ),
        );
      },
    );
  }
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
    Widget memberButton(DynamicMember member) => AppGlassButton(
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
              AppGlassButton(
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
                AppGlassButton(
                  onPressed: () => ref.invalidate(dynamicMembersProvider),
                  child: const Text('重试'),
                ),
              ],
            ),
          if (other.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('更多成员'),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final member in other) memberButton(member),
                    ],
                  ),
                ),
              ],
            ),
          heading('动态类型'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppGlassButton(
                selected: _draft.type == null,
                onPressed: () =>
                    setState(() => _draft = _draft.copyWith(clearType: true)),
                child: const Text('全部'),
              ),
              for (final type in DynamicType.values)
                AppGlassButton(
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
              AppGlassButton(
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
                AppGlassButton.icon(
                  tooltip: '清除日期',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(
                    () => _draft = _draft.copyWith(clearRange: true),
                  ),
                ),
            ],
          ),
          heading('排序'),
          AppGlassSegments<DynamicSort>(
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
            AppGlassButton(
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
                AppGlassButton(
                  onPressed: widget.onClose,
                  child: const Text('取消'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppGlassButton(
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
