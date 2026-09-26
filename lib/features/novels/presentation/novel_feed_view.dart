import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../shared/widgets/feed_offset_memory.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/auto_fill_viewport.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../../shared/widgets/feed_scroll_view.dart';
import '../../../shared/widgets/media_card_surface.dart';
import '../../../shared/widgets/app_panel.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/query_summary.dart';
import '../../content/presentation/content_images.dart';
import '../../content/presentation/content_search_control.dart';
import '../../content/application/fanart_feed_controller.dart' show FeedStatus;
import '../../content/presentation/feed_status_footer.dart';
import '../application/novel_feed_controller.dart';
import '../application/novel_providers.dart';
import '../domain/novel_repository.dart';
import 'novel_reader_page.dart';

/// Read-only novels from the dynamics archive.
class NovelFeedView extends ConsumerStatefulWidget {
  const NovelFeedView({super.key});

  @override
  ConsumerState<NovelFeedView> createState() => _NovelFeedViewState();
}

class _NovelFeedViewState extends ConsumerState<NovelFeedView>
    with FeedOffsetMemory {
  @override
  String get offsetStorageId => 'feed-offset-novels';

  ScrollController get _scrollController => feedScrollController();
  late final NovelFeedController _controller = ref.read(
    novelFeedControllerProvider,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.loadInitial();
    });
  }

  void _applyQuery(NovelQuery query) {
    _controller.applyQuery(query);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final state = _controller.state;
      return AutoFillViewport(
        controller: _scrollController,
        resetKey: _controller.generation,
        scrollResetKey: state.query,
        canLoadMore: state.status == FeedStatus.ready,
        onLoadMore: () => _controller.loadMore(automatic: true),
        child: _buildBody(state),
      );
    },
  );

  Widget _buildBody(NovelFeedState state) {
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
            FeedStatus.endOfList => FeedMessage.empty(
              noun: '小说',
              filtered: state.query != const NovelQuery(),
              onClear: () => _applyQuery(const NovelQuery()),
              onRefresh: _controller.refresh,
            ),
            _ => null,
          };
    return FeedScrollView(
      storageKey: const PageStorageKey('novel-feed'),
      controller: _scrollController,
      onRefresh: _controller.refresh,
      header: [
        if (state.status == FeedStatus.failed && state.items.isNotEmpty)
          FeedStaleNotice(failure: state.failure, onRetry: _controller.refresh),
        // The controls sit over the reading list they filter.
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppTokens.readingWidth + 32,
            ),
            child: _NovelFilters(
              query: state.query,
              total: state.status == FeedStatus.loadingFirstPage
                  ? null
                  : state.total,
              onChanged: _applyQuery,
            ),
          ),
        ),
      ],
      placeholder: placeholder,
      slivers: [
        // A reading list, like a bibliography: one column, ruled entries.
        SliverLayoutBuilder(
          builder: (context, constraints) {
            final side = math.max(
              16.0,
              (constraints.crossAxisExtent - AppTokens.readingWidth) / 2,
            );
            return SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: side),
              sliver: SliverList.separated(
                itemCount: state.items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) => _NovelCard(
                  key: ValueKey(state.items[index].identity),
                  item: state.items[index],
                ),
              ),
            );
          },
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

class _NovelFilters extends ConsumerStatefulWidget {
  const _NovelFilters({
    required this.query,
    required this.total,
    required this.onChanged,
  });
  final NovelQuery query;
  final int? total;
  final ValueChanged<NovelQuery> onChanged;
  @override
  ConsumerState<_NovelFilters> createState() => _NovelFiltersState();
}

class _NovelFiltersState extends ConsumerState<_NovelFilters> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 760;
      final query = widget.query;
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
                  children: [
                    Expanded(
                      child: ContentSearchControl(
                        value: query.keyword,
                        hint: query.scope == NovelSearchScope.all
                            ? '搜索标题、作者或正文'
                            : '搜索${query.scope.label}',
                        expanded: true,
                        onSubmitted: (keyword) =>
                            widget.onChanged(query.copyWith(keyword: keyword)),
                        filter: AppButton.icon(
                          tooltip: '筛选与排序',
                          icon: const Icon(Icons.tune),
                          selected: query != const NovelQuery(),
                          onPressed: () async {
                            if (wide) {
                              setState(() => _expanded = !_expanded);
                              return;
                            }
                            final next = await showAppPanel<NovelQuery>(
                              context: context,
                              builder: (context) => _NovelFilterPanel(
                                query: query,
                                onApply: (query) =>
                                    Navigator.pop(context, query),
                                onClose: () => Navigator.pop(context),
                              ),
                            );
                            if (next != null && mounted) widget.onChanged(next);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
                        child: _NovelFilterPanel(
                          key: ValueKey(query),
                          query: query,
                          embedded: true,
                          onApply: widget.onChanged,
                          onClose: () => setState(() => _expanded = false),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            QuerySummary(
              padding: EdgeInsets.zero,
              clearTooltip: '清除小说筛选',
              status: widget.total == null ? null : '${widget.total} 部',
              onClear: () => widget.onChanged(const NovelQuery()),
              applied: [
                if (query.keyword.isNotEmpty)
                  (
                    label: '“${query.keyword}”',
                    remove: () => widget.onChanged(query.copyWith(keyword: '')),
                  ),
                if (query.scope != NovelSearchScope.all)
                  (
                    label: '只搜${query.scope.label}',
                    remove: () => widget.onChanged(
                      query.copyWith(scope: NovelSearchScope.all),
                    ),
                  ),
                if (query.rating != NovelRatingFilter.all)
                  (
                    label: query.rating.label,
                    remove: () => widget.onChanged(
                      query.copyWith(rating: NovelRatingFilter.all),
                    ),
                  ),
                for (final character in query.characters)
                  (
                    label: character.wire,
                    remove: () => widget.onChanged(
                      query.copyWith(
                        characters: query.characters.difference({character}),
                      ),
                    ),
                  ),
                if (query.sort != NovelSort.newest)
                  (
                    label: query.sort.label,
                    remove: () => widget.onChanged(
                      query.copyWith(sort: NovelSort.newest),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

class _NovelFilterPanel extends ConsumerStatefulWidget {
  const _NovelFilterPanel({
    super.key,
    required this.query,
    required this.onApply,
    required this.onClose,
    this.embedded = false,
  });
  final NovelQuery query;
  final ValueChanged<NovelQuery> onApply;
  final VoidCallback onClose;
  final bool embedded;
  @override
  ConsumerState<_NovelFilterPanel> createState() => _NovelFilterPanelState();
}

class _NovelFilterPanelState extends ConsumerState<_NovelFilterPanel> {
  late NovelQuery _draft = widget.query;

  void _change(NovelQuery next) {
    setState(() => _draft = next);
    if (widget.embedded) widget.onApply(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final facets = ref.watch(novelFacetsProvider).valueOrNull;
    Widget group(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
    final groups = [
      group('角色', [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppButton(
              selected: _draft.characters.isEmpty,
              onPressed: () => _change(_draft.copyWith(characters: {})),
              child: const Text('全部'),
            ),
            for (final character in NovelCharacter.values)
              AppButton(
                selected: _draft.characters.contains(character),
                onPressed: () => _change(
                  _draft.copyWith(
                    characters: _draft.characters.contains(character)
                        ? ({..._draft.characters}..remove(character))
                        : {..._draft.characters, character},
                  ),
                ),
                child: Text(character.wire),
              ),
          ],
        ),
        if (_draft.characters.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('同时包含所选角色', style: theme.textTheme.bodySmall),
          ),
      ]),
      group('分级', [
        AppSegments<NovelRatingFilter>(
          values: NovelRatingFilter.values,
          selected: _draft.rating,
          labelOf: (value) => value.label,
          onChanged: (value) => _change(_draft.copyWith(rating: value)),
        ),
        if (facets != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              [
                for (final rating in NovelRatingFilter.values)
                  '${rating.label} ${facets.count(rating)}',
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
          ),
      ]),
      group('搜索范围', [
        AppSegments<NovelSearchScope>(
          values: NovelSearchScope.values,
          selected: _draft.scope,
          labelOf: (value) => value.label,
          onChanged: (value) => _change(_draft.copyWith(scope: value)),
        ),
      ]),
      group('排序', [
        AppSegments<NovelSort>(
          values: NovelSort.values,
          selected: _draft.sort,
          labelOf: (value) => value.label,
          onChanged: (value) => _change(_draft.copyWith(sort: value)),
        ),
      ]),
    ];
    final fields = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: widget.embedded
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Column(children: groups.take(2).toList())),
                const SizedBox(width: 24),
                Expanded(child: Column(children: groups.skip(2).toList())),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: groups,
            ),
    );
    return Column(
      mainAxisSize: widget.embedded ? MainAxisSize.min : MainAxisSize.max,
      children: [
        if (!widget.embedded)
          AppPanelHeader(
            title: '筛选小说',
            onClose: widget.onClose,
            actions: [
              AppButton(
                onPressed: () => _change(const NovelQuery()),
                child: const Text('重置'),
              ),
            ],
          ),
        if (widget.embedded)
          fields
        else
          Expanded(child: SingleChildScrollView(child: fields)),
        if (!widget.embedded)
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
}

class _NovelCard extends ConsumerWidget {
  const _NovelCard({super.key, required this.item});
  final NovelSummary item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final author = item.authorName.isEmpty ? '匿名作者' : item.authorName;
    final serif = theme.textTheme.bodyLarge?.copyWith(
      fontFamily: 'serif',
      fontFamilyFallback: const ['Songti SC', 'Noto Serif CJK SC'],
      height: 1.75,
      color: colors.onSurfaceVariant,
    );
    // An entry in a reading list: the title leads, then who and how long,
    // then a few lines of the text itself. No cover is invented.
    return MediaActionRegion(
      onTap: () => openNovel(context, item),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.title.isEmpty ? '无题' : item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
                  ),
                ),
                if (item.isR18) ...[
                  const SizedBox(width: 8),
                  const NovelR18Badge(),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                author,
                if (item.createdAt != null) formatNovelDate(item.createdAt!),
                formatNovelCharCount(item.charCount),
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            if (item.characters.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: NovelCharacterTags(characters: item.characters),
              ),
            const SizedBox(height: 10),
            if (item.isR18)
              Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '仅提供作品信息与原帖链接',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              )
            else ...[
              if (item.images.isNotEmpty) ...[
                ContentImageGallery(images: item.images, preview: true),
                const SizedBox(height: 10),
              ],
              Text(
                item.excerpt.isEmpty ? '暂无预览文本' : item.excerpt.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: serif,
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: AppButton(
                onPressed: item.isR18 && item.sourceUrl != null
                    ? () => openNovelSource(context, ref, item.sourceUrl!)
                    : () => openNovel(context, item),
                child: Text(
                  item.isR18
                      ? (item.sourceUrl == null ? '作品信息' : '查看原帖 ↗')
                      : '阅读全文',
                  style: TextStyle(color: colors.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
