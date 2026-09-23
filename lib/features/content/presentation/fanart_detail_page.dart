import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/app_page_bar.dart';
import '../../rules/application/feed_visibility.dart';
import 'package:flutter/material.dart';

import '../../handoff/domain/return_context.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/domain/content_identity.dart';
import '../../../core/domain/bilibili_id.dart';
import '../../creator/presentation/creator_link.dart';
import '../domain/fanart_repository.dart';
import 'fanart_image_viewer.dart';
import '../../library/application/content_snapshots.dart';
import '../../library/presentation/content_actions.dart';
import '../../library/presentation/history_recorder.dart';
import '../../library/presentation/library_common.dart';

/// Opens a fanart item where it can be seen: a video on Bilibili, anything
/// else in the app's own detail page.
void openFanart(
  BuildContext context,
  WidgetRef ref,
  FanartItem item, {
  ReturnTarget returnTo = ReturnTarget.today,
  String? channel,
}) {
  if (item.contentType == FanartContentType.video && item.sourceUrl != null) {
    openContentSource(
      context,
      ref,
      ContentSnapshots.fanart(item),
      url: item.sourceUrl,
      returnTo: returnTo,
      channel: channel,
    );
    return;
  }
  Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(builder: (_) => FanartDetailPage(item: item)));
}

/// Reading view for one fanart post.
///
/// The item is handed in from the list rather than re-fetched, so opening a
/// detail costs no extra request against the shared rate limit and returning
/// keeps the list exactly where it was.
class FanartDetailPage extends ConsumerWidget {
  const FanartDetailPage({required this.item, super.key});

  final FanartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final text = item.text.trim();
    return HistoryRecorder(
      item: ContentSnapshots.fanart(item),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppPageBar(
          title: Text(item.authorName.isEmpty ? '二创详情' : item.authorName),
          actions: [
            ContentActionsButton(
              item: ContentSnapshots.fanart(item),
              ruleSubject: RuleSubjects.fanart(item),
            ),
            if (item.sourceUrl != null)
              IconButton(
                tooltip: '打开原动态',
                icon: const Icon(Icons.open_in_new),
                onPressed: () => openContentSource(
                  context,
                  ref,
                  ContentSnapshots.fanart(item),
                  url: item.sourceUrl,
                ),
              ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final info = <Widget>[
              _AuthorRow(item: item),
              const SizedBox(height: 16),
              if (text.isNotEmpty)
                SelectableText(text, style: theme.textTheme.bodyLarge),
              if (item.images.isEmpty && text.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: Text('这条动态没有可显示的正文或图片')),
                ),
              _MetaRow(item: item),
            ];
            final images = <Widget>[
              for (var index = 0; index < item.images.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DetailImage(
                    item: item,
                    index: index,
                    onTap: () =>
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute<void>(
                            builder: (_) => FanartImageViewer(
                              images: item.images,
                              initial: index,
                            ),
                          ),
                        ),
                  ),
                ),
            ];
            if (constraints.maxWidth >= 1000 && item.images.isNotEmpty) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ListView(
                      key: const ValueKey('fanart-detail-gallery'),
                      padding: pageInsets(context, horizontal: 24),
                      children: images,
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: (constraints.maxWidth * .34).clamp(340, 440),
                    child: ListView(
                      key: const ValueKey('fanart-detail-info'),
                      padding: pageInsets(context, horizontal: 20),
                      children: info,
                    ),
                  ),
                ],
              );
            }
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: ListView(
                  padding: pageInsets(context),
                  children: [
                    ...info,
                    if (images.isNotEmpty) const SizedBox(height: 16),
                    ...images,
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AuthorRow extends ConsumerWidget {
  const _AuthorRow({required this.item});
  final FanartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mid =
        item.identity.source != ContentSource.doubanTopic &&
            validBilibiliMid(item.authorUid)
        ? item.authorUid
        : null;
    return Row(
      children: [
        CreatorLink(
          mid: mid,
          child: CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundImage: item.authorAvatarUrl == null
                ? null
                : NetworkImage(item.authorAvatarUrl.toString()),
            child: Text(
              item.authorName.isEmpty ? '?' : item.authorName.characters.first,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CreatorLink(
            mid: mid,
            child: Text(
              item.authorName.isEmpty ? '未知作者' : item.authorName,
              style: theme.textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (mid != null || item.authorSpaceUrl != null)
          TextButton(
            onPressed: mid != null
                ? () => openCreatorPage(context, mid)
                : () => ref
                      .read(externalLinkServiceProvider)
                      .open(item.authorSpaceUrl!),
            child: const Text('作者主页'),
          ),
      ],
    );
  }
}

/// Long vertical artwork is common here, so the image keeps its aspect ratio
/// instead of being cropped into a fixed box.
class _DetailImage extends StatelessWidget {
  const _DetailImage({
    required this.item,
    required this.index,
    required this.onTap,
  });

  final FanartItem item;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        child: Image.network(
          item.images[index].toString(),
          fit: BoxFit.fitWidth,
          width: double.infinity,
          errorBuilder: (context, error, stack) => Container(
            height: 160,
            color: theme.colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: Text(
              '图片加载失败',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : Container(
                  height: 160,
                  color: theme.colorScheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.item});
  final FanartItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = [
      item.category.wire,
      for (final tag in item.characterTags) tag.wire,
      if (item.viewCount != null) '播放 ${item.viewCount}',
      if (item.favoriteCount != null) '收藏 ${item.favoriteCount}',
    ];
    if (labels.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final label in labels)
            Chip(
              label: Text(label),
              visualDensity: VisualDensity.compact,
              labelStyle: theme.textTheme.labelSmall,
            ),
        ],
      ),
    );
  }
}
