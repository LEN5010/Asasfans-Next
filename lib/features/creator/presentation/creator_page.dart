import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/domain/bilibili_id.dart';
import '../../../shared/widgets/auto_fill_viewport.dart';
import '../../../shared/widgets/media_grid_delegate.dart';
import '../../../shared/widgets/retry_button.dart';
import '../../content/application/fanart_feed_controller.dart' show FeedStatus;
import '../../content/presentation/content_search_control.dart';
import '../../content/presentation/feed_status_footer.dart';
import '../../content/presentation/video_card.dart';
import '../../library/domain/library_models.dart';
import '../../library/presentation/local_subscribe_button.dart';
import '../../rules/application/feed_visibility.dart';
import '../../rules/presentation/rule_filter_scope.dart';
import '../application/creator_controller.dart';
import '../application/creator_providers.dart';
import '../domain/creator_repository.dart';
import 'creator_link.dart';

class CreatorPage extends ConsumerStatefulWidget {
  const CreatorPage({required this.mid, super.key});
  final String mid;
  @override
  ConsumerState<CreatorPage> createState() => _CreatorPageState();
}

class _CreatorPageState extends ConsumerState<CreatorPage> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!validBilibiliMid(widget.mid)) {
      return Scaffold(
        appBar: AppBar(title: const Text('UP 主页')),
        body: const Center(child: Text('UID 无效')),
      );
    }
    final controller = ref.watch(creatorControllerProvider(widget.mid));
    final state = controller.archives;
    return CreatorRouteScope(
      mid: widget.mid,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            controller.profile?.name ?? 'UP 主页',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              tooltip: '刷新主页',
              onPressed: controller.profileLoading || state.busy
                  ? null
                  : controller.refresh,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: '在 B 站打开 UP 主页',
              icon: const Icon(Icons.open_in_new),
              onPressed: () async {
                final opened = await ref
                    .read(externalLinkServiceProvider)
                    .open(Uri.https('space.bilibili.com', '/${widget.mid}'));
                if (!opened && context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('无法打开链接')));
                }
              },
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide =
                  constraints.maxWidth >= 1000 &&
                  MediaQuery.textScalerOf(context).scale(1) <= 1.6;
              final profile = _ProfilePanel(controller: controller);
              final archives = RuleFilterScope<VideoSummary>(
                items: state.items,
                subjectOf: RuleSubjects.video,
                allowPriority: false,
                unavailableBuilder: (status) => _scrollView(
                  controller,
                  wide: wide,
                  profile: profile,
                  placeholder: status,
                ),
                builder: (visible) => AutoFillViewport(
                  controller: _scroll,
                  resetKey: (controller.archiveGeneration, visible.epoch),
                  scrollResetKey: state.query,
                  canLoadMore: state.status == FeedStatus.ready,
                  onLoadMore: () => controller.loadMore(automatic: true),
                  child: _scrollView(
                    controller,
                    wide: wide,
                    profile: profile,
                    visible: visible,
                  ),
                ),
              );
              if (!wide) return archives;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 300,
                    child: SingleChildScrollView(child: profile),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: archives),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _scrollView(
    CreatorController controller, {
    required bool wide,
    required Widget profile,
    FeedVisibility<VideoSummary>? visible,
    Widget? placeholder,
  }) {
    final state = controller.archives;
    final items = visible?.items ?? const <VideoSummary>[];
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final columns = MediaGridDelegate.columnsFor(
          constraints.maxWidth,
          textScale: scaler.scale(1),
        );
        final width = MediaGridDelegate.cellWidth(
          constraints.maxWidth,
          columns,
        );
        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: CustomScrollView(
            key: PageStorageKey('creator-${widget.mid}'),
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (!wide) SliverToBoxAdapter(child: profile),
              SliverToBoxAdapter(
                child: _ArchiveToolbar(controller: controller),
              ),
              if (visible != null)
                SliverToBoxAdapter(child: RuleStatusBar(visibility: visible)),
              if (placeholder != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: placeholder,
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  sliver: SliverGrid.builder(
                    gridDelegate: MediaGridDelegate(
                      crossAxisCount: columns,
                      itemExtents: [
                        for (final item in items)
                          VideoCard.extentFor(item, width, scaler),
                      ],
                    ),
                    itemCount: items.length,
                    // This page is pushed on the root navigator with no named
                    // route, so a cold start cannot rebuild it. Keep the
                    // default rather than storing a target the restorer would
                    // have to invent a path for; a warm return still comes back
                    // here because the route is still on the stack.
                    itemBuilder: (_, index) => VideoCard(
                      key: ValueKey(items[index].identity),
                      video: items[index],
                    ),
                  ),
                ),
                if (items.isEmpty && state.status == FeedStatus.endOfList)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          state.items.isNotEmpty
                              ? '当前投稿已被屏蔽'
                              : state.query.keyword.isNotEmpty
                              ? '没有匹配的投稿'
                              : '还没有投稿',
                        ),
                      ),
                    ),
                  ),
                if (items.isNotEmpty || state.status != FeedStatus.endOfList)
                  SliverToBoxAdapter(
                    child: FeedStatusFooter(
                      status: state.status,
                      failure: state.failure,
                      onRetry: controller.loadMore,
                      onRefresh: controller.refreshArchives,
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ArchiveToolbar extends StatelessWidget {
  const _ArchiveToolbar({required this.controller});
  final CreatorController controller;
  @override
  Widget build(BuildContext context) {
    final state = controller.archives;
    void apply(CreatorArchiveQuery query) {
      if (!query.valid) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('搜索词无效')));
        return;
      }
      controller.applyQuery(query);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  state.total == null ? '投稿' : '投稿 · ${state.total}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ContentSearchControl(
                value: state.query.keyword,
                hint: '搜索投稿',
                onSubmitted: (value) =>
                    apply(state.query.copyWith(keyword: value)),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final order in CreatorArchiveOrder.values)
                ChoiceChip(
                  label: Text(order.label),
                  selected: state.query.order == order,
                  onSelected: (_) => apply(state.query.copyWith(order: order)),
                ),
              if (state.query.keyword.isNotEmpty)
                InputChip(
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      state.query.keyword,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  onDeleted: () => apply(state.query.copyWith(keyword: '')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel({required this.controller});
  final CreatorController controller;
  @override
  Widget build(BuildContext context) {
    final profile = controller.profile;
    final theme = Theme.of(context);
    final stats = <String>[
      if (profile?.followers != null) '${_count(profile!.followers!)} 粉丝',
      if (profile?.following != null) '${_count(profile!.following!)} 关注',
      if (profile?.likes != null) '${_count(profile!.likes!)} 获赞',
    ];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (profile?.banner != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                profile!.banner.toString(),
                height: 96,
                width: double.infinity,
                fit: BoxFit.cover,
                cacheWidth: 1000,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundImage: profile?.avatar == null
                    ? null
                    : ResizeImage(
                        NetworkImage(profile!.avatar.toString()),
                        width: 160,
                      ),
                onForegroundImageError: profile?.avatar == null
                    ? null
                    : (_, _) {},
                child: const Icon(Icons.person_outline, size: 30),
              ),
              LocalSubscribeButton(
                key: ValueKey(controller.mid),
                creator: LocalSubscription(
                  mid: controller.mid,
                  name: profile?.name ?? '',
                  avatar: profile?.avatar,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            profile?.name ?? 'UP ${controller.mid}',
            style: theme.textTheme.titleLarge,
          ),
          Text(
            'UID ${controller.mid}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                for (final stat in stats)
                  Text(stat, style: theme.textTheme.labelMedium),
              ],
            ),
          ],
          if (profile?.official.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text(
              profile!.official,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
          if (profile?.signature.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            SelectableText(
              profile!.signature,
              style: theme.textTheme.bodyMedium,
            ),
          ],
          if (controller.profileLoading)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
          if (controller.profileFailure != null) ...[
            const SizedBox(height: 12),
            Text(
              controller.profileFailure!.message,
              style: theme.textTheme.bodySmall,
            ),
            RetryButton(
              failure: controller.profileFailure,
              onRetry: controller.refreshProfile,
              label: '重试资料',
            ),
          ],
        ],
      ),
    );
  }

  static String _count(int value) =>
      value >= 10000 ? '${(value / 10000).toStringAsFixed(1)}万' : '$value';
}
