import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../shared/widgets/glass/app_glass_controls.dart';
import '../../content/application/content_providers.dart';
import '../../content/domain/dynamic_repository.dart';
import '../../content/presentation/dynamic_card.dart';
import '../../handoff/domain/return_context.dart';
import '../../rules/application/feed_visibility.dart';
import '../../rules/presentation/rule_filter_scope.dart';

/// A bounded set of large, naturally sized cards. Horizontal scrolling has no
/// timer or auto-play; the row's real content determines its height.
class OnThisDaySection extends ConsumerWidget {
  const OnThisDaySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            SizedBox(
              width: 200,
              child: AppGlassSegments<OnThisDaySort>(
                values: OnThisDaySort.values,
                selected: sort,
                labelOf: (value) => switch (value) {
                  OnThisDaySort.hot => '综合',
                  OnThisDaySort.likes => '点赞',
                  OnThisDaySort.comments => '评论',
                },
                onChanged: (value) =>
                    ref.read(onThisDaySortProvider.notifier).state = value,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
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
                AppGlassButton(
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
                      final width = math.min(420.0, constraints.maxWidth * .88);
                      return SingleChildScrollView(
                        key: const PageStorageKey('on-this-day-cards'),
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 16,
                          children: [
                            for (final post in visible.items)
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
