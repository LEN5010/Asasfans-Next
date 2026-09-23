import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/bilibili_id.dart';
import '../../../shared/widgets/glass/app_glass_controls.dart';
import '../../../shared/widgets/media_card_surface.dart';
import '../../../shared/widgets/media_cover.dart';
import '../../creator/presentation/creator_link.dart';
import '../../handoff/domain/return_context.dart';
import '../../library/application/content_snapshots.dart';
import '../../library/presentation/content_actions.dart';
import '../../library/presentation/library_common.dart';
import '../../rules/application/feed_visibility.dart';
import '../domain/dynamic_repository.dart';
import 'content_images.dart';
import 'dynamic_rich_text.dart';

String dynamicTypeLabel(DynamicType type) => switch (type) {
  DynamicType.text => '文字',
  DynamicType.image => '图文',
  DynamicType.video => '视频',
  DynamicType.forward => '转发',
  DynamicType.article => '专栏',
  DynamicType.live => '直播',
  DynamicType.other => '其他',
};

String dynamicTime(DateTime value) {
  final date = value.toUtc().add(const Duration(hours: 8));
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${pad(date.month)}-${pad(date.day)} ${pad(date.hour)}:${pad(date.minute)}';
}

class DynamicCard extends ConsumerStatefulWidget {
  const DynamicCard({
    super.key,
    required this.post,
    this.returnTo = ReturnTarget.contentChannel,
    this.historyPreview = false,
  });
  final DynamicPost post;
  final ReturnTarget returnTo;
  final bool historyPreview;

  @override
  ConsumerState<DynamicCard> createState() => _DynamicCardState();
}

class _DynamicCardState extends ConsumerState<DynamicCard> {
  bool _expanded = false;
  DynamicPost get post => widget.post;
  ReturnTarget get returnTo => widget.returnTo;

  @override
  Widget build(BuildContext context) {
    final preview = widget.historyPreview && !_expanded;
    final theme = Theme.of(context);
    final snapshot = ContentSnapshots.dynamic(post);
    void open(Uri uri) => openContentSource(
      context,
      ref,
      snapshot,
      url: uri,
      returnTo: returnTo,
      channel: returnTo == ReturnTarget.contentChannel ? 'dynamics' : null,
    );
    void actions() => showContentActions(
      context,
      snapshot,
      ruleSubject: RuleSubjects.dynamic(post),
    );
    final original = post.forwardedFrom;
    return MediaCardSurface(
      // Prose is selectable; only explicit media/source controls leave the app.
      onMore: actions,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                ContentAvatar(
                  name: post.member.name,
                  image: post.member.avatarUrl,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CreatorLink(
                        mid: post.member.bilibiliUid,
                        child: Text(
                          post.member.name,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (widget.historyPreview)
                            post.publishedAt == null
                                ? '往年的今天'
                                : '${post.publishedAt!.toUtc().add(const Duration(hours: 8)).year} 年的今天'
                          else if (post.publishedAt != null)
                            dynamicTime(post.publishedAt!),
                          dynamicTypeLabel(post.type),
                        ].join(' · '),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                MediaMoreButton(onPressed: actions),
              ],
            ),
            const SizedBox(height: 14),
            DynamicBody(
              text: post.text,
              maxLines: preview ? 4 : null,
              preview: preview,
              images: post.images,
              media: post.media,
              sourceUrl: post.sourceUrl,
              publishedAt: post.publishedAt,
              onOpen: open,
            ),
            if (original != null) ...[
              const SizedBox(height: 14),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CreatorLink(
                        mid: original.authorMid,
                        child: Text(
                          '转发自 @${original.authorName.isEmpty ? '原动态' : original.authorName}',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (original.publishedAt != null)
                            dynamicTime(original.publishedAt!),
                          dynamicTypeLabel(original.type),
                        ].join(' · '),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      DynamicBody(
                        text: original.text,
                        maxLines: preview ? 2 : null,
                        preview: preview,
                        images: original.images,
                        media: original.media,
                        sourceUrl: original.sourceUrl,
                        publishedAt: original.publishedAt,
                        onOpen: open,
                      ),
                      if (original.sourceUrl != null) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: AppGlassButton(
                            onPressed: () => open(original.sourceUrl!),
                            child: const Text('查看原文 ↗'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            if (widget.historyPreview)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AppGlassButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    child: Text(_expanded ? '收起正文' : '展开全文'),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('赞 ${post.likeCount}', style: theme.textTheme.bodySmall),
                Text(
                  '评论 ${post.commentCount}',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  '转发 ${post.forwardCount}',
                  style: theme.textTheme.bodySmall,
                ),
                if (post.sourceUrl != null)
                  AppGlassButton(
                    onPressed: () => open(post.sourceUrl!),
                    child: Text(
                      post.type == DynamicType.forward ? '查看这条转发 ↗' : '查看原动态 ↗',
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

/// Shared by the full dynamic feed and the home history cards. Covers are not
/// added to the photo set, and emoji never becomes a gallery thumbnail.
class DynamicBody extends StatelessWidget {
  const DynamicBody({
    super.key,
    required this.text,
    required this.images,
    required this.media,
    required this.onOpen,
    this.sourceUrl,
    this.publishedAt,
    this.maxLines,
    this.preview = false,
  });
  final String text;
  final List<Uri> images;
  final List<DynamicMedia> media;
  final ValueChanged<Uri> onOpen;
  final Uri? sourceUrl;
  final DateTime? publishedAt;
  final int? maxLines;
  final bool preview;

  @override
  Widget build(BuildContext context) {
    final cards = media
        .where(
          (item) =>
              item.kind != DynamicMediaKind.emoji &&
              item.kind != DynamicMediaKind.image &&
              (item.url != null ||
                  item.title.isNotEmpty ||
                  item.description.isNotEmpty ||
                  item.badge.isNotEmpty),
        )
        .toList();
    final coverUrls = {
      for (final item in cards)
        if (item.url != null) item.url!,
    };
    final photos = {
      ...images,
      for (final item in media)
        if (item.kind == DynamicMediaKind.image && item.url != null) item.url!,
    }.where((uri) => !coverUrls.contains(uri)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (text.isNotEmpty)
          DynamicRichText(text: text, media: media, maxLines: maxLines),
        if (photos.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: text.isEmpty ? 0 : 12),
            child: ContentImageGallery(
              images: photos,
              preview: preview,
              aspectRatios: {
                for (final item in media)
                  if (item.url != null && item.aspectRatio != null)
                    item.url!: item.aspectRatio!,
              },
            ),
          ),
        for (final item in (preview ? cards.take(1) : cards))
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _MediaCard(
              media: item,
              preview: preview,
              sourceUrl: sourceUrl,
              publishedAt: publishedAt,
              onOpen: onOpen,
            ),
          ),
      ],
    );
  }
}

/// Reservation copy is Shanghai-local. Unknown copy remains unknown, rather
/// than marking an undated archive card as an available future reservation.
DateTime? reservationTime(String description, DateTime? publishedAt) {
  if (publishedAt == null) return null;
  final clock = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(description);
  if (clock == null) return null;
  final published = publishedAt.toUtc().add(const Duration(hours: 8));
  final hour = int.parse(clock[1]!);
  final minute = int.parse(clock[2]!);
  if (hour > 23 || minute > 59) return null;
  var date = DateTime.utc(published.year, published.month, published.day);
  if (description.contains('明天')) {
    date = date.add(const Duration(days: 1));
  } else if (!description.contains('今天')) {
    final match = RegExp(
      r'(?:(\d{4})[-/.年])?(\d{1,2})[-/.月](\d{1,2})',
    ).firstMatch(description);
    if (match == null) return null;
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    date = DateTime.utc(
      match[1] == null ? published.year : int.parse(match[1]!),
      month,
      day,
    );
    if (date.month != month || date.day != day) return null;
    if (match[1] == null &&
        date
            .add(Duration(hours: hour, minutes: minute))
            .isBefore(published.subtract(const Duration(days: 1)))) {
      date = DateTime.utc(date.year + 1, month, day);
    }
  }
  return date.add(Duration(hours: hour - 8, minutes: minute));
}

class _MediaCard extends StatelessWidget {
  const _MediaCard({
    required this.media,
    required this.sourceUrl,
    required this.publishedAt,
    required this.onOpen,
    this.preview = false,
  });
  final bool preview;
  final DynamicMedia media;
  final Uri? sourceUrl;
  final DateTime? publishedAt;
  final ValueChanged<Uri> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reserve = media.kind == DynamicMediaKind.reserve;
    final time = reserve
        ? reservationTime(media.description, publishedAt)
        : null;
    final expired =
        reserve &&
        ((time != null && !DateTime.now().isBefore(time)) ||
            RegExp(
              r'已结束|已过期|已失效',
            ).hasMatch('${media.badge} ${media.actionText}'));
    final target = media.kind == DynamicMediaKind.video && validBvid(media.ref)
        ? Uri.https('www.bilibili.com', '/video/${media.ref}')
        : sourceUrl;
    final title = media.title.replaceFirst(RegExp(r'^直播预约[：:]\s*'), '');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: reserve
            ? theme.colorScheme.tertiaryContainer.withValues(alpha: .35)
            : theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (media.url != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: InkWell(
                onTap: target == null || expired ? null : () => onOpen(target),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    MediaCover(
                      image: media.url,
                      aspectRatio: preview
                          ? 16 / 9
                          : media.aspectRatio ?? 16 / 9,
                      badge: media.durationText.isEmpty
                          ? null
                          : media.durationText,
                      video: media.kind == DynamicMediaKind.video,
                    ),
                    if (media.kind == DynamicMediaKind.video && target != null)
                      AppGlassButton.icon(
                        onPressed: () => onOpen(target),
                        icon: const Icon(Icons.play_arrow),
                        tooltip: '去 B 站看',
                      ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reserve
                      ? '直播预约'
                      : media.kind == DynamicMediaKind.video
                      ? '视频动态'
                      : '相关内容',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title.isEmpty ? '查看相关内容' : title,
                  maxLines: preview ? 2 : null,
                  overflow: preview ? TextOverflow.ellipsis : TextOverflow.clip,
                  style: theme.textTheme.titleMedium,
                ),
                if (media.description.isNotEmpty || media.badge.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      [
                        media.description,
                        media.badge,
                      ].where((value) => value.isNotEmpty).join(' · '),
                      maxLines: preview ? 2 : null,
                      overflow: preview
                          ? TextOverflow.ellipsis
                          : TextOverflow.clip,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                if (target != null || expired)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: expired
                        ? Text('已过期', style: theme.textTheme.labelMedium)
                        : AppGlassButton(
                            onPressed: () => onOpen(target!),
                            child: Text(
                              reserve
                                  ? (time == null ? '查看预约 ↗' : '前往预约 ↗')
                                  : media.kind == DynamicMediaKind.video
                                  ? '去 B 站看 ↗'
                                  : '查看详情 ↗',
                            ),
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
