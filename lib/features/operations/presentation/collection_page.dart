import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../core/domain/content_identity.dart';
import '../../../core/network/api_failure.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/app_page_bar.dart';
import '../../../shared/widgets/media_image_policy.dart';
import '../../content/presentation/fanart_image_viewer.dart';
import '../../handoff/application/handoff_providers.dart';
import '../../handoff/domain/return_context.dart';
import '../../library/domain/library_models.dart';
import '../../library/presentation/library_common.dart';
import '../data/collection_repository.dart';
import '../domain/fanart_collection.dart';

class FanartCollectionPage extends ConsumerStatefulWidget {
  const FanartCollectionPage({required this.collectionId, super.key});
  final String collectionId;

  @override
  ConsumerState<FanartCollectionPage> createState() =>
      _FanartCollectionPageState();
}

class _FanartCollectionPageState extends ConsumerState<FanartCollectionPage> {
  String _group = '';
  String _query = '';

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: const AppPageBar(title: Text('活动专题')),
    body: ref
        .watch(collectionProvider(widget.collectionId))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error is ApiFailure ? error.message : '专题加载失败'),
                  const SizedBox(height: 12),
                  AppButton(
                    onPressed: () =>
                        ref.invalidate(collectionProvider(widget.collectionId)),
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          ),
          data: (collection) => LayoutBuilder(
            builder: (context, constraints) {
              final padding = pageInsets(context, horizontal: 20);
              final width = constraints.maxWidth - padding.horizontal;
              final columns = width >= 1040
                  ? 3
                  : width >= 680
                  ? 2
                  : 1;
              final entries = collection.filteredEntries(
                group: _group,
                query: _query,
              );
              return RefreshIndicator(
                onRefresh: () =>
                    ref.refresh(collectionProvider(widget.collectionId).future),
                child: CustomScrollView(
                  key: PageStorageKey('collection-${collection.id}'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(20, padding.top, 20, 20),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              collection.title,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 20),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 720),
                              child: AppCard(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      collection.dates,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontFeatures: [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(collection.venue),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: Divider(height: 1),
                                    ),
                                    Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.surfaceContainerHigh,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.newspaper_outlined,
                                            size: 22,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            collection.sourceAuthor,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        AppButton.withIcon(
                                          tonal: true,
                                          onPressed: () => _openCollectionLink(
                                            context,
                                            ref,
                                            collection.id,
                                            collection.sourceUrl,
                                          ),
                                          icon: const Icon(
                                            Icons.open_in_new,
                                            size: 18,
                                          ),
                                          label: const Text('查看原帖'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final group in ['', ...collection.groups])
                                  AppChoice(
                                    label: Text(group.isEmpty ? '全部' : group),
                                    selected: _group == group,
                                    onSelected: (_) =>
                                        setState(() => _group = group),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              onChanged: (value) =>
                                  setState(() => _query = value),
                              textInputAction: TextInputAction.search,
                              decoration: const InputDecoration(
                                hintText: '搜索物料或作者',
                                prefixIcon: Icon(Icons.search),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '物料 ${entries.length}',
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (entries.isEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('没有找到相关物料')),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(20, 0, 20, padding.bottom),
                        sliver: SliverMasonryGrid.count(
                          crossAxisCount: columns,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childCount: entries.length,
                          itemBuilder: (context, index) => _CollectionCard(
                            key: ValueKey('${entries[index].id}:$_group'),
                            collectionId: collection.id,
                            entry: entries[index],
                            group: _group,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
  );
}

class _CollectionCard extends ConsumerStatefulWidget {
  const _CollectionCard({
    required this.collectionId,
    required this.entry,
    required this.group,
    super.key,
  });

  final String collectionId;
  final FanartCollectionEntry entry;
  final String group;

  @override
  ConsumerState<_CollectionCard> createState() => _CollectionCardState();
}

class _CollectionCardState extends ConsumerState<_CollectionCard> {
  int _selected = 0;

  @override
  void didUpdateWidget(_CollectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entry != oldWidget.entry) _selected = 0;
  }

  void _openImages(List<Uri> images) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => FanartImageViewer(
          images: images,
          initial: _selected,
          onOpenOriginal: (url) =>
              _openCollectionLink(context, ref, widget.collectionId, url),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final images = entry.galleryImages(widget.group);
    final colors = Theme.of(context).colorScheme;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.groups.join(' · '),
                  style: TextStyle(color: colors.primary, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  entry.title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (images.isNotEmpty) ...[
            LayoutBuilder(
              builder: (context, constraints) => InkWell(
                onTap: () => _openImages(images),
                child: Semantics(
                  button: true,
                  label: '放大查看${entry.title}，第 ${_selected + 1} 张',
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: ColoredBox(
                      color: colors.surfaceContainerHigh,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Image(
                          image: MediaImagePolicy.preview(
                            images[_selected],
                            logicalWidth: constraints.maxWidth - 24,
                            devicePixelRatio: MediaQuery.devicePixelRatioOf(
                              context,
                            ),
                          ),
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              const Center(child: Text('图片加载失败')),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (images.length > 1)
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(10),
                  itemCount: images.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => Semantics(
                    selected: index == _selected,
                    button: true,
                    label: '第 ${index + 1} 张',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _selected = index),
                      child: Container(
                        width: 56,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: index == _selected
                                ? colors.primary
                                : colors.outlineVariant,
                            width: 2,
                          ),
                        ),
                        child: Image(
                          image: MediaImagePolicy.preview(
                            images[index],
                            logicalWidth: 46,
                            devicePixelRatio: MediaQuery.devicePixelRatioOf(
                              context,
                            ),
                          ),
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.broken_image_outlined, size: 20),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (entry.summary.isNotEmpty) ...[
                  Text(entry.summary),
                  const SizedBox(height: 12),
                ],
                if (entry.authorUid == null)
                  Text(entry.author)
                else
                  AppButton(
                    onPressed: () => _openCollectionLink(
                      context,
                      ref,
                      widget.collectionId,
                      Uri.https('space.bilibili.com', '/${entry.authorUid}'),
                    ),
                    child: Text(entry.author),
                  ),
                const SizedBox(height: 8),
                if (images.isNotEmpty)
                  AppButton.withIcon(
                    onPressed: () => _openImages(images),
                    icon: const Icon(Icons.zoom_in),
                    label: const Text('查看大图'),
                  ),
                AppButton.withIcon(
                  tonal: true,
                  onPressed: () => openContentSource(
                    context,
                    ref,
                    ContentSnapshot(
                      identity: ContentIdentity(
                        source: entry.isVideo
                            ? ContentSource.bilibiliVideo
                            : ContentSource.bilibiliDynamic,
                        value: entry.id,
                      ),
                      title: entry.title,
                      body: entry.summary,
                      authorName: entry.author,
                      authorId: entry.authorUid ?? '',
                      images: entry.images,
                      kind: entry.isVideo
                          ? LibraryMediaKind.video
                          : LibraryMediaKind.image,
                    ),
                    url: entry.sourceUrl,
                    returnTo: ReturnTarget.contentChannel,
                    channel: 'fanart',
                    query: {'collectionId': widget.collectionId},
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(entry.isVideo ? '看原视频' : '看原动态'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openCollectionLink(
  BuildContext context,
  WidgetRef ref,
  String collectionId,
  Uri url,
) async {
  final result = await ref
      .read(handoffCoordinatorProvider)
      .open(
        url: url,
        target: ReturnTarget.contentChannel,
        channel: 'fanart',
        query: {'collectionId': collectionId},
      );
  if (!result.accepted &&
      result.outcome != HandoffOutcome.duplicate &&
      context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('无法打开链接')));
  }
}
