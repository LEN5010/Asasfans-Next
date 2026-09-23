import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/auto_fill_viewport.dart';
import '../../../shared/widgets/media_grid_delegate.dart';
import '../../../shared/widgets/retry_button.dart';
import '../../content/presentation/video_card.dart';
import '../../creator/presentation/creator_link.dart';
import '../../handoff/domain/return_context.dart';
import '../../handoff/presentation/watch_on_bilibili.dart';
import '../../library/presentation/library_common.dart';
import '../../library/presentation/library_pages.dart';
import '../../rules/application/feed_visibility.dart';
import '../../rules/presentation/rule_filter_scope.dart';
import '../application/subscription_feed_controller.dart';
import '../application/subscription_providers.dart';
import '../domain/subscription_updates.dart';

class SubscriptionFeedView extends ConsumerStatefulWidget {
  const SubscriptionFeedView({super.key});
  @override
  ConsumerState<SubscriptionFeedView> createState() =>
      _SubscriptionFeedViewState();
}

class _SubscriptionFeedViewState extends ConsumerState<SubscriptionFeedView> {
  final _scroll = ScrollController();
  bool _unread = false;
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(subscriptionFeedControllerProvider);
    return RuleFilterScope<VideoSummary>(
      items: controller.items,
      subjectOf: RuleSubjects.video,
      allowPriority: false,
      builder: (visible) {
        final items = _unread
            ? visible.items
                  .where(
                    (item) =>
                        controller.readsReady &&
                        controller.readStates[item.identity.value] != true,
                  )
                  .toList()
            : visible.items;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('全部'),
                    selected: !_unread,
                    onSelected: (_) => setState(() => _unread = false),
                  ),
                  ChoiceChip(
                    label: const Text('未读'),
                    selected: _unread,
                    onSelected: (_) => setState(() => _unread = true),
                  ),
                  IconButton(
                    tooltip: '刷新订阅更新',
                    onPressed: controller.loading ? null : controller.refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                  IconButton(
                    tooltip: '管理订阅',
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SubscriptionsPage(),
                          ),
                        ),
                    icon: const Icon(Icons.people_outline),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.done_all, size: 18),
                    label: const Text('标记当前已读'),
                    onPressed:
                        !controller.readsReady ||
                            controller.savingReads ||
                            items.isEmpty
                        ? null
                        : () async {
                            final ids = List<String>.unmodifiable(
                              items.map((v) => v.identity.value),
                            );
                            if (await confirmLibraryAction(
                                  context,
                                  '标记这 ${ids.length} 条更新为已读？',
                                ) &&
                                context.mounted) {
                              await libraryAction(
                                context,
                                () => controller.mark(ids, read: true),
                              );
                            }
                          },
                  ),
                ],
              ),
            ),
            RuleStatusBar(visibility: visible),
            if (controller.issues.isNotEmpty)
              TextButton.icon(
                icon: const Icon(Icons.error_outline, size: 18),
                label: Text('${controller.issues.length} 位 UP 加载失败'),
                onPressed: () => _showIssues(controller),
              ),
            if (controller.readFailure != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('已读状态读取失败'),
                    TextButton(
                      onPressed: controller.reloadReads,
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: AutoFillViewport(
                controller: _scroll,
                resetKey: (controller.generation, visible.epoch, _unread),
                scrollResetKey: (_unread, controller.generation),
                canLoadMore:
                    controller.canLoadMore &&
                    (!_unread || controller.readsReady),
                onLoadMore: () => controller.loadMore(automatic: true),
                child: LayoutBuilder(
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
                    final receiptHeight = math.max(
                      40.0,
                      scaler.scale(14) * 1.5 + 16,
                    );
                    return RefreshIndicator(
                      onRefresh: controller.refresh,
                      child: CustomScrollView(
                        controller: _scroll,
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            sliver: SliverGrid.builder(
                              gridDelegate: MediaGridDelegate(
                                crossAxisCount: columns,
                                itemExtents: [
                                  for (final item in items)
                                    VideoCard.extentFor(item, width, scaler) +
                                        receiptHeight,
                                ],
                              ),
                              itemCount: items.length,
                              itemBuilder: (_, index) {
                                final item = items[index];
                                final read =
                                    controller.readStates[item
                                        .identity
                                        .value] ==
                                    true;
                                return Column(
                                  children: [
                                    Expanded(
                                      child: VideoCard(
                                        video: item,
                                        origin: const WatchOrigin(
                                          target: ReturnTarget.contentChannel,
                                          channel: 'subscriptions',
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      height: receiptHeight,
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton.icon(
                                          icon: Icon(
                                            read
                                                ? Icons.check_circle_outline
                                                : Icons.radio_button_unchecked,
                                            size: 16,
                                          ),
                                          label: Text(
                                            controller.readsReady
                                                ? (read ? '已读' : '标为已读')
                                                : '状态未知',
                                          ),
                                          onPressed:
                                              controller.savingReads ||
                                                  !controller.readsReady
                                              ? null
                                              : () => libraryAction(
                                                  context,
                                                  () => controller.mark([
                                                    item.identity.value,
                                                  ], read: !read),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: _footer(controller, items.isEmpty),
                          ),
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: MediaQuery.paddingOf(context).bottom,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _footer(SubscriptionFeedController controller, bool empty) {
    Widget child;
    if (controller.loading) {
      child = const SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(),
      );
    } else if (controller.storageFailure != null ||
        controller.failure != null) {
      child = Column(
        children: [
          Text(
            controller.storageFailure?.message ?? controller.failure!.message,
            textAlign: TextAlign.center,
          ),
          RetryButton(
            failure: controller.failure,
            onRetry: controller.needsRefresh
                ? controller.refresh
                : controller.loadMore,
            label: controller.needsRefresh ? '刷新' : '重试',
          ),
        ],
      );
    } else if (_unread && controller.readFailure != null) {
      child = const Text('未读状态暂不可用');
    } else if (controller.totalCreators == 0 && controller.initialized) {
      child = const Text('还没有本地订阅');
    } else if (controller.checkedCreators < controller.totalCreators) {
      child = Text(
        '已检查 ${controller.checkedCreators} / ${controller.totalCreators} 位 UP',
      );
    } else if (controller.end) {
      child = Text(
        controller.issues.isNotEmpty
            ? (empty ? '暂未取得投稿' : '已加载可用投稿')
            : empty
            ? (_unread
                  ? '没有未读更新'
                  : controller.items.isNotEmpty
                  ? '当前投稿已被屏蔽'
                  : '还没有投稿')
            : '没有更多了',
      );
    } else {
      child = const SizedBox(height: 4);
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: child),
      ),
    );
  }

  Future<void> _showIssues(SubscriptionFeedController controller) async {
    final issues = controller.issues;
    final retry = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
            child: Row(
              children: [
                const Expanded(child: Text('加载失败')),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: issues.length,
              itemBuilder: (_, index) {
                final issue = issues[index];
                return ListTile(
                  title: Text(
                    issue.creator.name.isEmpty
                        ? 'UP ${issue.creator.mid}'
                        : issue.creator.name,
                  ),
                  subtitle: Text(issue.failure.message),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => openCreatorPage(context, issue.creator.mid),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: controller.loading
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('重新检查'),
            ),
          ),
        ],
      ),
    );
    if (retry == true && mounted) await controller.retryFailedCreators();
  }
}
