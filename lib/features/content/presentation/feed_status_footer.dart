import 'package:flutter/material.dart';

import '../../../core/network/api_failure.dart';
import '../../../shared/widgets/retry_button.dart';
import '../application/fanart_feed_controller.dart' show FeedStatus;

class FeedStatusFooter extends StatelessWidget {
  const FeedStatusFooter({
    required this.status,
    required this.failure,
    required this.onRetry,
    required this.onRefresh,
    super.key,
  });
  final FeedStatus status;
  final ApiFailure? failure;
  final VoidCallback onRetry;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: switch (status) {
      FeedStatus.appending || FeedStatus.loadingFirstPage => const Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      // A failed refresh is said at the top of the list (FeedStaleNotice).
      FeedStatus.appendFailed || FeedStatus.stalled => Column(
        children: [
          Text(
            status == FeedStatus.stalled
                ? '后面没有新的内容了，可以刷新后再试'
                : '加载更多失败：${failure?.message ?? '请重试'}',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          RetryButton(
            failure: failure,
            onRetry: status == FeedStatus.appendFailed ? onRetry : onRefresh,
            label: status == FeedStatus.stalled ? '刷新' : '重试',
          ),
        ],
      ),
      FeedStatus.endOfList => Center(
        child: Text(
          '没有更多了',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
      _ => const SizedBox(height: 4),
    },
  );
}
