import '../../../shared/widgets/app_page_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/time/calendar_time.dart';
import '../../../shared/widgets/auto_fill_viewport.dart';
import '../../account/presentation/account_page.dart';
import '../../content/application/fanart_feed_controller.dart' show FeedStatus;
import '../../content/presentation/fanart_image_viewer.dart';
import '../../content/presentation/feed_status_footer.dart';
import '../../creator/presentation/creator_link.dart';
import '../application/comment_providers.dart';
import '../domain/comments.dart';

class CommentList extends ConsumerStatefulWidget {
  const CommentList({required this.query, this.header, super.key});
  final CommentQuery query;
  final Widget? header;
  @override
  ConsumerState<CommentList> createState() => _CommentListState();
}

class _CommentListState extends ConsumerState<CommentList> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(commentControllerProvider(widget.query));
    final visible = controller.visible;
    final pinned = controller.pinned.map((c) => c.id).toSet();
    final root = controller.root;
    return AutoFillViewport(
      controller: _scroll,
      resetKey: (controller, controller.generation),
      scrollResetKey: (widget.query, controller, controller.query.order),
      canLoadMore: controller.status == FeedStatus.ready,
      onLoadMore: () => controller.loadMore(automatic: true),
      child: RefreshIndicator(
        onRefresh: controller.refresh,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (widget.header != null) SliverToBoxAdapter(child: widget.header),
            if (root != null)
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    CommentTile(comment: root, showReplies: false),
                    const Divider(height: 1),
                  ],
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${widget.query.root == null ? '评论' : '回复'}${controller.total == null ? '' : ' · ${controller.total}'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (widget.query.root == null)
                      for (final order in CommentOrder.values)
                        ChoiceChip(
                          label: Text(order.label),
                          selected: controller.query.order == order,
                          onSelected: (value) {
                            if (value && controller.query.order != order) {
                              controller.refresh(order: order);
                            }
                          },
                        ),
                    IconButton(
                      tooltip: '刷新评论',
                      onPressed: controller.busy ? null : controller.refresh,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
            ),
            SliverList.builder(
              itemCount: visible.length,
              itemBuilder: (context, index) => CommentTile(
                key: ValueKey(visible[index].id),
                comment: visible[index],
                pinned: pinned.contains(visible[index].id),
              ),
            ),
            if (controller.closed)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('评论区已关闭')),
                ),
              )
            else if (visible.isEmpty &&
                controller.status == FeedStatus.endOfList)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(widget.query.root == null ? '还没有评论' : '还没有回复'),
                  ),
                ),
              ),
            if (controller.failure?.kind == ApiFailureKind.loginRequired)
              SliverToBoxAdapter(
                child: Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.login),
                    label: const Text('登录 B 站'),
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const AccountPage(),
                          ),
                        ),
                  ),
                ),
              ),
            if (!controller.closed &&
                (visible.isNotEmpty ||
                    controller.status != FeedStatus.endOfList))
              SliverToBoxAdapter(
                child: FeedStatusFooter(
                  status: controller.status,
                  failure: controller.failure,
                  onRetry: controller.loadMore,
                  onRefresh: controller.refresh,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CommentTile extends StatelessWidget {
  const CommentTile({
    required this.comment,
    this.pinned = false,
    this.showReplies = true,
    super.key,
  });
  final BiliComment comment;
  final bool pinned, showReplies;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final at = comment.createdAt == null
        ? null
        : CalendarTime.inShanghai(comment.createdAt!);
    final replies =
        showReplies &&
        comment.root == '0' &&
        ((comment.replyCount ?? 0) > 0 || comment.previews.isNotEmpty);
    void openReplies() => Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppPageBar(title: const Text('评论回复')),
          body: SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: CommentList(
                  query: CommentQuery(oid: comment.oid, root: comment.id),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CreatorLink(
            mid: comment.authorId,
            child: CircleAvatar(
              radius: 18,
              foregroundImage: comment.avatar == null
                  ? null
                  : ResizeImage(
                      NetworkImage(comment.avatar.toString()),
                      width: 100,
                    ),
              onForegroundImageError: comment.avatar == null ? null : (_, _) {},
              child: const Icon(Icons.person_outline, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CreatorLink(
                  mid: comment.authorId,
                  child: Text(
                    comment.authorName.isEmpty ? '未知用户' : comment.authorName,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: 6),
                if (pinned)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '置顶',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                if (comment.message.isNotEmpty)
                  SelectableText(
                    comment.message,
                    style: theme.textTheme.bodyMedium,
                  ),
                if (comment.pictures.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < comment.pictures.length; i++)
                          Semantics(
                            button: true,
                            label: '查看评论图片 ${i + 1}',
                            child: InkWell(
                              onTap: () =>
                                  Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => FanartImageViewer(
                                        images: comment.pictures,
                                        initial: i,
                                      ),
                                    ),
                                  ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  comment.pictures[i].toString(),
                                  width: 88,
                                  height: 88,
                                  fit: BoxFit.cover,
                                  cacheWidth: 240,
                                  errorBuilder: (_, _, _) => const SizedBox(
                                    width: 88,
                                    height: 88,
                                    child: Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (at != null)
                      Text(
                        '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}',
                        style: theme.textTheme.labelSmall,
                      ),
                    if (comment.likeCount != null)
                      Text(
                        '${comment.likeCount} 赞',
                        style: theme.textTheme.labelSmall,
                      ),
                    if (comment.likedByCreator)
                      Text(
                        'UP 主觉得很赞',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                  ],
                ),
                if (replies) ...[
                  if (comment.previews.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: InkWell(
                        onTap: openReplies,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final reply in comment.previews.take(3))
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    '${reply.authorName.isEmpty ? '未知用户' : reply.authorName}：${reply.message}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  TextButton(
                    onPressed: openReplies,
                    child: Text(
                      comment.replyCount == null
                          ? '查看回复'
                          : '查看 ${comment.replyCount} 条回复',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
