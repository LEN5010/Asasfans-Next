import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_failure.dart';
import '../../app/theme/app_tokens.dart';
import 'app_controls.dart';
import 'app_motion.dart';
import 'retry_button.dart';

/// A feed body that runs under the floating page bar. Filters and status rows
/// lead the scroll extent instead of pinning a second toolbar, and loading,
/// error and empty states keep those controls reachable.
class FeedScrollView extends StatefulWidget {
  const FeedScrollView({
    required this.controller,
    required this.onRefresh,
    this.header = const [],
    this.slivers = const [],
    this.placeholder,
    this.storageKey,
    super.key,
  });
  final ScrollController controller;
  final Future<void> Function() onRefresh;
  final List<Widget> header;
  final List<Widget> slivers;

  /// Replaces [slivers] with a state that fills the rest of the viewport.
  final Widget? placeholder;
  final Key? storageKey;

  @override
  State<FeedScrollView> createState() => _FeedScrollViewState();
}

class _FeedScrollViewState extends State<FeedScrollView>
    with SingleTickerProviderStateMixin {
  // Content fades in when it replaces a state; later pages append instantly.
  late final _reveal = AnimationController(
    vsync: this,
    value: widget.placeholder == null ? 1 : 0,
  );

  @override
  void didUpdateWidget(FeedScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placeholder != null && widget.placeholder == null) {
      _reveal
        ..duration = appMotion(context, AppTokens.controlMotion)
        ..forward(from: 0);
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final reveal = CurvedAnimation(parent: _reveal, curve: Curves.easeOutCubic);
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      edgeOffset: padding.top,
      child: CustomScrollView(
        key: widget.storageKey,
        controller: widget.controller,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(top: padding.top + 4),
            sliver: SliverList.list(children: widget.header),
          ),
          if (widget.placeholder case final placeholder?)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.only(bottom: padding.bottom),
                child: AppFadeSwitcher(
                  phase: placeholder.runtimeType,
                  child: placeholder,
                ),
              ),
            )
          else ...[
            for (final sliver in widget.slivers)
              SliverFadeTransition(opacity: reveal, sliver: sliver),
            SliverToBoxAdapter(child: SizedBox(height: padding.bottom + 8)),
          ],
        ],
      ),
    );
  }
}

/// A centered feed state; failures carry the cooldown-aware retry action.
/// Any other state that has a next step names it with [actionLabel].
class FeedMessage extends StatelessWidget {
  const FeedMessage({
    required this.icon,
    required this.text,
    this.detail,
    this.failure,
    this.onRetry,
    this.actionLabel,
    this.onAction,
    super.key,
  });
  final IconData icon;
  final String text;

  /// A quieter second line: why, or what to try.
  final String? detail;
  final ApiFailure? failure;
  final VoidCallback? onRetry;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// The empty state of a list query: nothing matching what is applied says
  /// so and offers to clear it; nothing at all offers a refresh.
  factory FeedMessage.empty({
    required String noun,
    required bool filtered,
    required VoidCallback onClear,
    required VoidCallback onRefresh,
    String clearLabel = '清除条件',
  }) => filtered
      ? FeedMessage(
          icon: Icons.search_off_outlined,
          text: '没有符合条件的$noun',
          detail: '换个条件，或清除条件看全部$noun',
          actionLabel: clearLabel,
          onAction: onClear,
        )
      : FeedMessage(
          icon: Icons.inbox_outlined,
          text: '这里暂时还没有$noun',
          detail: '来源还没有返回内容，稍后可以再刷新',
          actionLabel: '刷新',
          onAction: onRefresh,
        );

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            RetryButton(failure: failure, onRetry: onRetry, filled: true),
          ] else if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 16),
            AppButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}

/// Everything the source returned is hidden by the user's own rules. That is
/// neither an empty source nor an error, so it says which, and where to
/// change it.
class FeedAllHiddenMessage extends StatelessWidget {
  const FeedAllHiddenMessage({required this.count, super.key});
  final int count;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.filter_alt_off_outlined,
            size: 44,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text('已加载的 $count 条内容都被你的规则屏蔽', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          AppButton(
            onPressed: () => context.go('/mine/rules'),
            child: const Text('查看内容规则'),
          ),
        ],
      ),
    ),
  );
}

/// A refresh failed while earlier results are still on screen. Said at the
/// top, where the reader is, rather than only at the end of the list: what
/// is shown is the last successful load, and a retry is one tap.
class FeedStaleNotice extends StatelessWidget {
  const FeedStaleNotice({
    required this.failure,
    required this.onRetry,
    super.key,
  });
  final ApiFailure? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Semantics(
        liveRegion: true,
        child: Material(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '刷新失败，下面是上次加载的内容'
                    '${failure == null ? '' : '（${failure!.message}）'}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                RetryButton(failure: failure, onRetry: onRetry),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
