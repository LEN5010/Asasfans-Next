import 'package:flutter/material.dart';

import '../../core/network/api_failure.dart';
import '../../app/theme/app_tokens.dart';
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
class FeedMessage extends StatelessWidget {
  const FeedMessage({
    required this.icon,
    required this.text,
    this.failure,
    this.onRetry,
    super.key,
  });
  final IconData icon;
  final String text;
  final ApiFailure? failure;
  final VoidCallback? onRetry;

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
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            RetryButton(failure: failure, onRetry: onRetry, filled: true),
          ],
        ],
      ),
    ),
  );
}
