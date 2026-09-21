import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/domain/bilibili_id.dart';
import '../../../core/domain/content_identity.dart';
import '../../../core/time/calendar_time.dart';
import '../../../shared/widgets/media_cover.dart';
import '../../../shared/widgets/retry_button.dart';
import '../../account/presentation/account_page.dart';
import '../../../core/network/api_failure.dart';
import '../../comments/domain/comments.dart';
import '../../comments/presentation/comment_list.dart';
import '../../creator/presentation/creator_link.dart';
import '../../handoff/application/handoff_providers.dart';
import '../../handoff/presentation/watch_on_bilibili.dart';
import '../../library/application/content_snapshots.dart';
import '../../library/domain/library_models.dart';
import '../../library/presentation/content_actions.dart';
import '../../library/presentation/history_recorder.dart';
import '../../library/presentation/local_subscribe_button.dart';
import '../../rules/application/feed_visibility.dart';
import '../application/video_providers.dart';
import '../domain/video_detail.dart';

Future<void> openVideoDetail(BuildContext context, String bvid) async {
  if (!validBvid(bvid)) return;
  await Navigator.of(
    context,
    rootNavigator: true,
  ).push<void>(MaterialPageRoute(builder: (_) => VideoDetailPage(bvid: bvid)));
}

class VideoDetailPage extends ConsumerWidget {
  const VideoDetailPage({required this.bvid, super.key});
  final String bvid;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!validBvid(bvid)) {
      return Scaffold(
        appBar: AppBar(title: const Text('视频详情')),
        body: const Center(child: Text('视频编号无效')),
      );
    }
    final controller = ref.watch(videoDetailProvider(bvid));
    final detail = controller.detail;
    final snapshot = detail == null
        ? ContentSnapshot(
            identity: ContentIdentity(
              source: ContentSource.bilibiliVideo,
              value: bvid,
            ),
            title: bvid,
            body: '',
            authorName: '',
            kind: LibraryMediaKind.video,
          )
        : ContentSnapshots.video(detail.video);
    final scaffold = Scaffold(
      appBar: AppBar(
        title: const Text('视频详情'),
        actions: [
          if (detail != null)
            ContentActionsButton(
              item: snapshot,
              ruleSubject: RuleSubjects.video(detail.video),
            ),
          IconButton(
            tooltip: '刷新详情',
            onPressed: controller.loading ? null : controller.refresh,
            icon: const Icon(Icons.refresh),
          ),
          // Same handoff as the panel button, so the two actions on one screen
          // cannot disagree about what opening this video means. ListenableBuilder
          // is what makes the busy state visible here: the provider hands back
          // one long-lived coordinator, so watching it alone never rebuilds.
          ListenableBuilder(
            listenable: ref.watch(handoffCoordinatorProvider),
            builder: (context, _) => IconButton(
              tooltip: '在 B 站打开视频',
              onPressed:
                  ref.read(handoffCoordinatorProvider).busy || detail == null
                  ? null
                  : () => watchOnBilibili(context, ref, detail.video),
              icon: const Icon(Icons.open_in_new),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (controller.loading) const LinearProgressIndicator(),
            if (controller.failure != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(controller.failure!.message),
                    RetryButton(
                      failure: controller.failure,
                      onRetry: controller.loading ? null : controller.refresh,
                    ),
                    if (controller.failure!.kind ==
                        ApiFailureKind.loginRequired)
                      TextButton(
                        onPressed: () =>
                            Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const AccountPage(),
                              ),
                            ),
                        child: const Text('登录 B 站'),
                      ),
                  ],
                ),
              ),
            if (detail != null)
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final panel = _VideoPanel(
                      key: ValueKey(bvid),
                      detail: detail,
                    );
                    if (constraints.maxWidth >= 1100 &&
                        MediaQuery.textScalerOf(context).scale(1) <= 1.5) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 3,
                            child: SingleChildScrollView(
                              key: const ValueKey('video-details-column'),
                              child: panel,
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(
                            flex: 2,
                            child: CommentList(
                              key: ValueKey(detail.aid),
                              query: CommentQuery(oid: detail.aid),
                            ),
                          ),
                        ],
                      );
                    }
                    return CommentList(
                      key: ValueKey(detail.aid),
                      query: CommentQuery(oid: detail.aid),
                      header: panel,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
    // Recording a loaded detail is not evidence of any playback.
    return HistoryRecorder(
      key: ValueKey(bvid),
      item: snapshot,
      enabled: detail != null,
      child: scaffold,
    );
  }
}

class _VideoPanel extends ConsumerWidget {
  const _VideoPanel({required this.detail, super.key});
  final VideoDetail detail;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final video = detail.video;
    final controller = ref.watch(videoDetailProvider(video.identity.value));
    final part = controller.selectedPart ?? detail.parts.first;
    final date = video.publishedAt == null
        ? null
        : CalendarTime.inShanghai(video.publishedAt!);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: MediaCover(
              image: video.coverUrl,
              aspectRatio: 16 / 9,
              video: true,
            ),
          ),
          const SizedBox(height: 16),
          SelectableText(video.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              if (video.viewCount != null)
                Text('${video.viewCount} 播放', style: theme.textTheme.bodySmall),
              if (video.likeCount != null)
                Text('${video.likeCount} 赞', style: theme.textTheme.bodySmall),
              if (detail.favoriteCount != null)
                Text(
                  '${detail.favoriteCount} 收藏',
                  style: theme.textTheme.bodySmall,
                ),
              if (date != null)
                Text(
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
          const SizedBox(height: 16),
          CreatorLink(
            mid: video.creatorId,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  foregroundImage: video.creatorAvatarUrl == null
                      ? null
                      : ResizeImage(
                          NetworkImage(video.creatorAvatarUrl.toString()),
                          width: 120,
                        ),
                  onForegroundImageError: video.creatorAvatarUrl == null
                      ? null
                      : (_, _) {},
                  child: const Icon(Icons.person_outline),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    video.creatorName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              LocalSubscribeButton(
                key: ValueKey(video.creatorId),
                creator: LocalSubscription(
                  mid: video.creatorId,
                  name: video.creatorName,
                  avatar: video.creatorAvatarUrl,
                ),
              ),
              // The detail page is a secondary entry: a return goes back to the
              // list that led here, not to this page.
              ListenableBuilder(
                listenable: ref.watch(handoffCoordinatorProvider),
                builder: (context, _) => FilledButton.icon(
                  onPressed: ref.read(handoffCoordinatorProvider).busy
                      ? null
                      : () => watchOnBilibili(
                          context,
                          ref,
                          video,
                          part: detail.parts.length > 1 ? part.number : null,
                          redirect: detail.redirectUrl,
                        ),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('在 B 站播放'),
                ),
              ),
            ],
          ),
          if (detail.parts.length > 1) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.playlist_play),
              label: Text(
                '分 P · ${part.number}/${detail.parts.length} · ${part.title}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onPressed: () async {
                final selected = await showModalBottomSheet<String>(
                  context: context,
                  useRootNavigator: true,
                  useSafeArea: true,
                  isScrollControlled: true,
                  showDragHandle: true,
                  constraints: const BoxConstraints(maxWidth: 650),
                  builder: (context) => SizedBox(
                    height: MediaQuery.sizeOf(context).height * .7,
                    child: ListView.builder(
                      itemCount: detail.parts.length,
                      itemBuilder: (context, index) {
                        final entry = detail.parts[index];
                        return ListTile(
                          selected: entry.cid == part.cid,
                          title: Text('P${entry.number} · ${entry.title}'),
                          subtitle: entry.duration == null
                              ? null
                              : Text(_duration(entry.duration!)),
                          trailing: entry.cid == part.cid
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () => Navigator.pop(context, entry.cid),
                        );
                      },
                    ),
                  ),
                );
                if (context.mounted && selected != null) {
                  controller.selectPart(selected);
                }
              },
            ),
          ],
          if (video.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            SelectableText(
              video.description,
              style: theme.textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _duration(Duration value) =>
      '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';
}
