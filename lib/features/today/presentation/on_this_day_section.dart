import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/network/api_failure.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../content/application/content_providers.dart';
import '../../content/domain/dynamic_repository.dart';
import '../../content/presentation/dynamic_card.dart';
import '../../handoff/domain/return_context.dart';
import '../../rules/application/feed_visibility.dart';
import '../../rules/presentation/rule_filter_scope.dart';

/// A small, bounded history shelf with equal-height summaries, no autoplay.
/// It runs to the page edges; [inset] keeps the heading and first card
/// on the page margin while scrolled cards leave at the screen edge.
class OnThisDaySection extends ConsumerStatefulWidget {
  const OnThisDaySection({super.key, this.inset = EdgeInsets.zero});
  final EdgeInsets inset;

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
      duration: appMotion(context, AppTokens.controlMotion),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final posts = ref.watch(onThisDayProvider);
    final sort = ref.watch(onThisDaySortProvider);
    final arrows = MediaQuery.sizeOf(context).width >= 760;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: widget.inset,
          child: Row(
            children: [
              // Large type wraps the sort choice below the title.
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '历史上的今天',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    MenuAnchor(
                      menuChildren: [
                        for (final value in OnThisDaySort.values)
                          MenuItemButton(
                            onPressed: () =>
                                ref.read(onThisDaySortProvider.notifier).state =
                                    value,
                            leadingIcon: value == sort
                                ? const Icon(Icons.check)
                                : null,
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
                        onPressed: () =>
                            menu.isOpen ? menu.close() : menu.open(),
                      ),
                    ),
                  ],
                ),
              ),
              if (arrows) ...[
                AppButton.icon(
                  tooltip: '上一张历史',
                  onPressed: () => _move(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                AppButton.icon(
                  tooltip: '下一张历史',
                  onPressed: () => _move(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        AppFadeSwitcher(
          phase: asyncPhase(posts),
          child: posts.when(
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
                  Padding(
                    padding: widget.inset,
                    child: RuleStatusBar(visibility: visible),
                  ),
                  if (visible.items.isEmpty)
                    Padding(
                      padding: widget.inset.add(
                        const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        '往年今天还没有记录',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final room =
                            constraints.maxWidth - widget.inset.horizontal;
                        // Narrow shelves show one card and a peek of the
                        // next, snapping card by card.
                        final snap = room < 600;
                        final width = snap ? room * .86 : math.min(300.0, room);
                        // The endpoint supplies at most eight history items,
                        // so equal heights may measure every card.
                        return SingleChildScrollView(
                          controller: _scroll,
                          scrollDirection: Axis.horizontal,
                          padding: widget.inset,
                          physics: snap ? _SnapPhysics(width + 12) : null,
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Settles a drag on the nearest card, like a page view with a peek.
class _SnapPhysics extends ScrollPhysics {
  const _SnapPhysics(this.extent, {super.parent});
  final double extent;

  @override
  _SnapPhysics applyTo(ScrollPhysics? ancestor) =>
      _SnapPhysics(extent, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final tolerance = toleranceFor(position);
    var card = position.pixels / extent;
    if (velocity < -tolerance.velocity) {
      card -= .5;
    } else if (velocity > tolerance.velocity) {
      card += .5;
    }
    final target = (card.roundToDouble() * extent).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < tolerance.distance) return null;
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }
}
