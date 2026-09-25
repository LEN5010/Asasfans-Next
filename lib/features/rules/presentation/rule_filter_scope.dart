import '../../../shared/widgets/app_panel.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/app_controls.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/feed_visibility.dart';
import '../application/rules_providers.dart';
import '../domain/content_rules.dart';
import '../application/rules_controller.dart';
import 'rule_common.dart';

class RuleFilterScope<T> extends ConsumerStatefulWidget {
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
  ConsumerState<RuleFilterScope<T>> createState() => _RuleFilterScopeState<T>();
}

class _RuleFilterScopeState<T> extends ConsumerState<RuleFilterScope<T>> {
  // One remembered projection. Feed states and rule states are immutable, so
  // the same list and the same rules object always project the same way;
  // anything else (new page, rule edit, expiry tick) is a new object.
  List<T>? _items;
  RulesState? _policy;
  bool? _allowPriority;
  RuleSubject Function(T)? _subjectOf;
  FeedVisibility<T>? _projection;

  FeedVisibility<T> _project(RulesState policy) {
    final items = widget.items;
    if (_projection == null ||
        !identical(_items, items) ||
        !identical(_policy, policy) ||
        !identical(_subjectOf, widget.subjectOf) ||
        _allowPriority != widget.allowPriority) {
      _projection = projectFeed(
        items,
        widget.subjectOf,
        policy,
        allowPriority: widget.allowPriority,
      );
      _items = items;
      _policy = policy;
      _allowPriority = widget.allowPriority;
      _subjectOf = widget.subjectOf;
    }
    return _projection!;
  }

  @override
  Widget build(BuildContext context) {
    final unavailableBuilder = widget.unavailableBuilder;
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
              AppButton(
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
    return widget.builder(_project(policy));
  }
}

class RuleStatusBar<T> extends StatelessWidget {
  const RuleStatusBar({required this.visibility, super.key});
  final FeedVisibility<T> visibility;
  @override
  Widget build(BuildContext context) {
    final hidden = visibility.userHidden;
    if (hidden.isEmpty &&
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
          if (hidden.isNotEmpty)
            AppButton.withIcon(
              icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
              label: Text('已屏蔽 ${hidden.length}'),
              onPressed: () => showAppPanel<void>(
                context: context,

                maxWidth: 640,
                builder: (_) => _HiddenItems(items: hidden),
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
  const _HiddenItems({required this.items});
  final List<HiddenContent<T>> items;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const AppPanelHeader(title: '屏蔽记录'),
      Expanded(
        child: ListView.builder(
          itemCount: items.length,
          itemBuilder: (_, index) {
            final entry = items[index];
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
