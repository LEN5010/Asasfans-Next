import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/feed_visibility.dart';
import '../application/rules_providers.dart';
import '../domain/content_rules.dart';
import 'rule_common.dart';

class RuleFilterScope<T> extends ConsumerWidget {
  const RuleFilterScope({
    required this.items,
    required this.subjectOf,
    required this.builder,
    this.allowPriority = true,
    this.unavailableBuilder,
    super.key,
  });
  final List<T> items;
  final RuleSubject Function(T) subjectOf;
  final Widget Function(FeedVisibility<T>) builder;
  final bool allowPriority;
  final Widget Function(Widget status)? unavailableBuilder;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policy = ref.watch(rulesControllerProvider);
    if (policy.loading) {
      const status = Center(
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(),
        ),
      );
      return unavailableBuilder?.call(status) ?? status;
    }
    if (!policy.ready) {
      final status = Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('内容规则读取失败'),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () =>
                    ref.read(rulesControllerProvider.notifier).reload(),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
      return unavailableBuilder?.call(status) ?? status;
    }
    return builder(
      projectFeed(items, subjectOf, policy, allowPriority: allowPriority),
    );
  }
}

class RuleStatusBar<T> extends StatelessWidget {
  const RuleStatusBar({required this.visibility, super.key});
  final FeedVisibility<T> visibility;
  @override
  Widget build(BuildContext context) {
    if (visibility.hidden.isEmpty &&
        visibility.tagsUnknownCount == 0 &&
        !visibility.prioritized) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (visibility.prioritized)
            const Chip(
              label: Text('订阅优先'),
              visualDensity: VisualDensity.compact,
            ),
          if (visibility.hidden.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
              label: Text('已屏蔽 ${visibility.hidden.length}'),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                useRootNavigator: true,
                useSafeArea: true,
                showDragHandle: true,
                constraints: const BoxConstraints(maxWidth: 640),
                builder: (_) => _HiddenItems(visibility: visibility),
              ),
            ),
          if (visibility.tagsUnknownCount > 0)
            Text(
              'Tag 未知 ${visibility.tagsUnknownCount}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
        ],
      ),
    );
  }
}

class _HiddenItems<T> extends StatelessWidget {
  const _HiddenItems({required this.visibility});
  final FeedVisibility<T> visibility;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
        child: Row(
          children: [
            const Expanded(child: Text('屏蔽记录')),
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
          itemCount: visibility.hidden.length,
          itemBuilder: (_, index) {
            final entry = visibility.hidden[index];
            return ListTile(
              title: Text(
                entry.subject.displayTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  ruleScopeLabel(entry.subject.identity.source.name),
                  entry.subject.identity.value,
                  for (final match in entry.evaluation.matches.take(3))
                    '${match.field} · ${match.value}',
                  if (entry.evaluation.matches.length > 3)
                    '另 ${entry.evaluation.matches.length - 3} 条规则',
                ].join('\n'),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        ),
      ),
    ],
  );
}
