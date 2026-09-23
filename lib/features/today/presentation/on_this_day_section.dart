import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../content/application/content_providers.dart';
import '../../content/domain/dynamic_repository.dart';
import '../../content/presentation/dynamic_card.dart';
import '../../handoff/domain/return_context.dart';
import '../../rules/application/feed_visibility.dart';
import '../../rules/presentation/rule_filter_scope.dart';

/// A small, bounded history shelf with natural-height summaries, no autoplay.
class OnThisDaySection extends ConsumerStatefulWidget {
  const OnThisDaySection({super.key});

  @override
  ConsumerState<OnThisDaySection> createState() => _OnThisDaySectionState();
}

class _OnThisDaySectionState extends ConsumerState<OnThisDaySection> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _move(int direction) {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      (_scroll.offset + direction * _scroll.position.viewportDimension * .88)
          .clamp(0, _scroll.position.maxScrollExtent),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final posts = ref.watch(onThisDayProvider);
    final sort = ref.watch(onThisDaySortProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('历史上的今天', style: Theme.of(context).textTheme.titleMedium),
            MenuAnchor(
              menuChildren: [
                for (final value in OnThisDaySort.values)
                  MenuItemButton(
                    onPressed: () =>
                        ref.read(onThisDaySortProvider.notifier).state = value,
                    leadingIcon: value == sort ? const Icon(Icons.check) : null,
                    child: Text(switch (value) {
                      OnThisDaySort.hot => '综合热度',
                      OnThisDaySort.likes => '点赞',
                      OnThisDaySort.comments => '评论',
                    }),
                  ),
              ],
              builder: (context, menu, _) => AppButton.withIcon(
                tooltip: '历史排序',
                icon: const Icon(Icons.expand_more),
                label: Text(switch (sort) {
                  OnThisDaySort.hot => '综合',
                  OnThisDaySort.likes => '点赞',
                  OnThisDaySort.comments => '评论',
                }),
                onPressed: () => menu.isOpen ? menu.close() : menu.open(),
              ),
            ),
            if (MediaQuery.sizeOf(context).width >= 760)
              AppButton.icon(
                tooltip: '上一张历史',
                onPressed: () => _move(-1),
                icon: const Icon(Icons.chevron_left),
              ),
            if (MediaQuery.sizeOf(context).width >= 760)
              AppButton.icon(
                tooltip: '下一张历史',
                onPressed: () => _move(1),
                icon: const Icon(Icons.chevron_right),
              ),
          ],
        ),
        const SizedBox(height: 6),
        posts.when(
          loading: () => const SizedBox(
            height: 64,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Text(error is ApiFailure ? error.message : '内容加载失败'),
                const SizedBox(height: 8),
                AppButton(
                  onPressed: () => ref.invalidate(onThisDayProvider),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
          data: (raw) => RuleFilterScope(
            items: raw,
            subjectOf: RuleSubjects.dynamic,
            builder: (visible) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RuleStatusBar(visibility: visible),
                if (visible.items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      '往年今天还没有记录',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = math.min(300.0, constraints.maxWidth * .9);
                      // The endpoint supplies at most eight history items;
                      // natural card heights need no cross-card measurement.
                      return SingleChildScrollView(
                        key: const PageStorageKey('on-this-day-cards'),
                        controller: _scroll,
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final (index, post)
                                in visible.items.indexed) ...[
                              if (index > 0) const SizedBox(width: 12),
                              SizedBox(
                                width: width,
                                child: DynamicCard(
                                  key: ValueKey(post.identity),
                                  post: post,
                                  historyPreview: true,
                                  returnTo: ReturnTarget.today,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
