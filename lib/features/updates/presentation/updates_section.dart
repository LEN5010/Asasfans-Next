import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../handoff/domain/return_context.dart';
import '../../library/presentation/library_common.dart';
import '../application/update_providers.dart';
import 'update_card.dart';
import 'updates_page.dart';

/// Today's "what happened since you were last here" module.
///
/// It loads and fails on its own: a source the update pass could not reach
/// leaves this block with a note, and the rest of Today keeps working. It shows
/// what is waiting rather than a full history, and the inbox holds the rest.
class UpdatesSection extends ConsumerWidget {
  const UpdatesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentUpdatesProvider);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('最近更新', style: theme.textTheme.titleMedium)),
            TextButton(
              onPressed: () => context.go('/mine/updates'),
              child: const Text('全部'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const UpdateStatusBanner(),
        recent.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Text(libraryError(error)),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => ref.invalidate(recentUpdatesProvider),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
          data: (events) => events.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '暂时没有新的更新',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (final event in events)
                      // A return from here lands on Today, which is where the
                      // user actually left from.
                      UpdateCard(event: event, returnTo: ReturnTarget.today),
                  ],
                ),
        ),
      ],
    );
  }
}

/// The bell that carries the unread count.
///
/// The badge appears only once a real count has been read. A missing count is
/// not rendered as zero: the app does not claim an empty inbox it has not
/// looked at.
class UpdatesBellButton extends ConsumerWidget {
  const UpdatesBellButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(unreadUpdateCountProvider).valueOrNull;
    final unread = counts?.unread ?? 0;
    return IconButton(
      tooltip: '应用内更新',
      onPressed: () => context.go('/mine/updates'),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: const Icon(Icons.notifications_none),
      ),
    );
  }
}
