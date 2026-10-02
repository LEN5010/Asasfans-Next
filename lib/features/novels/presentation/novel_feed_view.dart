import 'package:flutter/material.dart';

import '../../../shared/widgets/feed_offset_memory.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/auto_fill_viewport.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../../shared/widgets/feed_scroll_view.dart';
import '../../../shared/widgets/media_card_surface.dart';
import '../../../shared/widgets/media_image_policy.dart';
import '../../../shared/widgets/sliver_content_masonry.dart';
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
        // The controls sit over the cards they filter, from the same edge.
        Align(
          alignment: AlignmentDirectional.centerStart,
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
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          // Cards of their own height: tags and a two-line title add to
          // some. One column on a phone, more as the window widens.
          sliver: SliverContentMasonry(
            itemCount: state.items.length,
            minColumnWidth: 280,
            wideMinColumnWidth: 280,
            maxColumns: 4,
            itemBuilder: (context, index) => _NovelCard(
              key: ValueKey(state.items[index].identity),
              item: state.items[index],
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
  bool _expanded = false;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 600;
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
                          onApply: (next) {
                            setState(() => _expanded = false);
                            widget.onChanged(next);
                          },
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

/// A novel as a card, after the archive site: who wrote it and when, who
/// it is about, a few lines of the text in an inset box, then the title
/// and its length. The box keeps one height, so a row of cards lines up.
class _NovelCard extends ConsumerWidget {
  const _NovelCard({super.key, required this.item});
  final NovelSummary item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = theme.textTheme.labelSmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final author = item.authorName.isEmpty ? '匿名作者' : item.authorName;
    final excerpt = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: 'serif',
      fontFamilyFallback: const ['Songti SC', 'Noto Serif CJK SC'],
      height: 1.6,
      color: colors.onSurface.withValues(alpha: .8),
    );
    // Four lines of the excerpt, at the reader's text size.
    final box =
        MediaQuery.textScalerOf(context).scale(excerpt?.fontSize ?? 14) *
            1.6 *
            4 +
        24;
    return MediaCardSurface(
      onTap: () => openNovel(context, item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ContentAvatar(
                      name: item.authorName,
                      size: MediaQuery.textScalerOf(context).scale(32),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            item.createdAt == null
                                ? '豆瓣同人'
                                : formatNovelDate(
                                    item.createdAt!,
                                    includeTime: true,
                                  ),
                            style: muted,
                          ),
                        ],
                      ),
                    ),
                    if (item.isR18) ...[
                      const SizedBox(width: 8),
                      const NovelR18Badge(),
                    ],
                  ],
                ),
                if (item.characters.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  NovelCharacterTags(characters: item.characters),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.inputRadius),
              child: ColoredBox(
                color: colors.surfaceContainerHighest.withValues(alpha: .6),
                child: SizedBox(
                  height: box,
                  child: item.isR18
                      ? const _HiddenText()
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (item.images.isNotEmpty)
                              _Thumbnails(images: item.images.take(2)),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  item.excerpt.isEmpty
                                      ? '暂无预览文本'
                                      : item.excerpt.trim(),
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: excerpt,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Text(
              item.title.isEmpty ? '无题' : item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
          const Divider(height: 13, indent: 14, endIndent: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 6, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    formatNovelCharCount(item.charCount),
                    style: muted,
                  ),
                ),
                // The whole card opens the novel; only the original post,
                // a different place, is a button of its own.
                if (item.isR18 && item.sourceUrl != null)
                  AppButton(
                    onPressed: () =>
                        openNovelSource(context, ref, item.sourceUrl!),
                    child: Text(
                      '查看原帖 ↗',
                      style: muted?.copyWith(color: colors.primary),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                    child: Text(
                      item.isR18 ? '作品信息 →' : '阅读全文 →',
                      style: muted?.copyWith(color: colors.primary),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Up to two pictures from the post, stacked down the box's leading edge.
/// Decorative: the card opens the novel, whose page shows them in full.
class _Thumbnails extends StatelessWidget {
  const _Thumbnails({required this.images});
  final Iterable<Uri> images;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: SizedBox(
        width: 88,
        child: Column(
          spacing: 1,
          children: [
            for (final uri in images)
              Expanded(
                child: Image(
                  image: MediaImagePolicy.preview(
                    uri,
                    logicalWidth: 88,
                    devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                  ),
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      ColoredBox(color: colors.surfaceContainerHigh),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Where an R18 work's excerpt would be: the archive never serves its text,
/// so the box holds shapes of lines under a label, not words.
class _HiddenText extends StatelessWidget {
  const _HiddenText();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    const widths = [.94, .8, .97, .62];
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final width in widths)
                FractionallySizedBox(
                  widthFactor: width,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: colors.onSurfaceVariant.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 8,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: .9),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                child: Text(
                  '正文已遮挡',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
