import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_icons.dart';
import '../../../shared/widgets/auto_fill_viewport.dart';
import '../../../shared/widgets/feed_scroll_view.dart';
import '../../../shared/widgets/media_card_surface.dart';
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

class _NovelFeedViewState extends ConsumerState<NovelFeedView> {
  final _scrollController = ScrollController();
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
            FeedStatus.endOfList => const FeedMessage(
              icon: Icons.search_off_outlined,
              text: '没有符合条件的小说',
            ),
            _ => null,
          };
    return FeedScrollView(
      storageKey: const PageStorageKey('novel-feed'),
      controller: _scrollController,
      onRefresh: _controller.refresh,
      header: [
        _NovelFilters(
          query: state.query,
          total: state.status == FeedStatus.loadingFirstPage
              ? null
              : state.total,
          onChanged: _applyQuery,
        ),
      ],
      placeholder: placeholder,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          sliver: SliverConstrainedCrossAxis(
            maxExtent: 760,
            sliver: SliverList.separated(
              itemCount: state.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _NovelCard(item: state.items[index]),
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

/// Filters lead the list and scroll with it: search, sort and characters on
/// the first row, rating on the second.
class _NovelFilters extends ConsumerWidget {
  const _NovelFilters({
    required this.query,
    required this.total,
    required this.onChanged,
  });

  final NovelQuery query;
  final int? total;
  final ValueChanged<NovelQuery> onChanged;

  Future<void> _search(BuildContext context) async {
    final result = await showDialog<({String keyword, NovelSearchScope scope})>(
      context: context,
      builder: (_) =>
          _NovelSearchDialog(value: query.keyword, scope: query.scope),
    );
    if (result == null) return;
    onChanged(query.copyWith(keyword: result.keyword, scope: result.scope));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final facets = ref.watch(novelFacetsProvider).valueOrNull;
    final scope = query.scope == NovelSearchScope.all
        ? ''
        : '${query.scope.label}：';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              if (query.keyword.isEmpty)
                ActionChip(
                  avatar: const Icon(AppIcons.search, size: 18),
                  label: const Text('搜索'),
                  onPressed: () => _search(context),
                )
              else
                InputChip(
                  avatar: const Icon(AppIcons.search, size: 18),
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(
                      '$scope${query.keyword}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  onPressed: () => _search(context),
                  onDeleted: () => onChanged(query.copyWith(keyword: '')),
                ),
              const SizedBox(width: 8),
              PopupMenuButton<NovelSort>(
                tooltip: '排序',
                initialValue: query.sort,
                onSelected: (sort) => onChanged(query.copyWith(sort: sort)),
                itemBuilder: (_) => [
                  for (final sort in NovelSort.values)
                    PopupMenuItem(value: sort, child: Text(sort.label)),
                ],
                child: Chip(
                  avatar: const Icon(Icons.sort, size: 18),
                  label: Text(query.sort.label),
                ),
              ),
              for (final character in NovelCharacter.values) ...[
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(character.wire),
                  selected: query.characters.contains(character),
                  onSelected: (selected) => onChanged(
                    query.copyWith(
                      characters: {
                        ...query.characters.where(
                          (value) => selected || value != character,
                        ),
                        if (selected) character,
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              for (final rating in NovelRatingFilter.values) ...[
                ChoiceChip(
                  label: Text(
                    facets == null
                        ? rating.label
                        : '${rating.label} ${facets.count(rating)}',
                  ),
                  selected: query.rating == rating,
                  onSelected: (_) => onChanged(query.copyWith(rating: rating)),
                ),
                const SizedBox(width: 8),
              ],
              if (total != null) ...[
                const SizedBox(width: 4),
                Text(
                  // Several characters narrow to works tagged with all of them.
                  '共 $total 部${query.characters.length > 1 ? ' · 同时包含所选角色' : ''}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Search is applied on submit, never per keystroke, to spare the shared
/// rate limit.
class _NovelSearchDialog extends StatefulWidget {
  const _NovelSearchDialog({required this.value, required this.scope});
  final String value;
  final NovelSearchScope scope;
  @override
  State<_NovelSearchDialog> createState() => _NovelSearchDialogState();
}

class _NovelSearchDialogState extends State<_NovelSearchDialog> {
  late final _controller = TextEditingController(text: widget.value);
  late NovelSearchScope _scope = widget.scope;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit([String? value]) => Navigator.pop(context, (
    keyword: (value ?? _controller.text).trim(),
    scope: _scope,
  ));

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('搜索小说'),
    content: SizedBox(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 200,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: '标题、作者或正文',
              counterText: '',
            ),
            onSubmitted: _submit,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final scope in NovelSearchScope.values)
                ChoiceChip(
                  label: Text(scope.label),
                  selected: _scope == scope,
                  onSelected: (_) => setState(() => _scope = scope),
                ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      if (widget.value.isNotEmpty)
        TextButton(onPressed: () => _submit(''), child: const Text('清除')),
      FilledButton(onPressed: _submit, child: const Text('搜索')),
    ],
  );
}

class _NovelCard extends StatelessWidget {
  const _NovelCard({required this.item});
  final NovelSummary item;

  static final _space = RegExp(r'\s+');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final meta = [
      item.authorName.isEmpty ? '匿名作者' : item.authorName,
      if (item.createdAt != null) formatNovelDate(item.createdAt!),
    ].join(' · ');
    return MediaCardSurface(
      onTap: () => openNovel(context, item),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.title.isEmpty ? '无题' : item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (item.isR18) ...[
                  const SizedBox(width: 8),
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: NovelR18Badge(),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(color: muted),
            ),
            if (item.characters.isNotEmpty) ...[
              const SizedBox(height: 8),
              NovelCharacterTags(characters: item.characters),
            ],
            const SizedBox(height: 8),
            if (item.isR18)
              Row(
                children: [
                  Icon(Icons.lock_outline, size: 16, color: muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'R18 作品，应用内不显示正文，可在详情中前往原帖',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ),
                ],
              )
            else
              Text(
                item.excerpt.isEmpty
                    ? '暂无预览文本'
                    : item.excerpt.replaceAll(_space, ' '),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  formatNovelCharCount(item.charCount),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const Spacer(),
                Text(
                  item.isR18 ? '查看原帖' : '阅读全文',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
