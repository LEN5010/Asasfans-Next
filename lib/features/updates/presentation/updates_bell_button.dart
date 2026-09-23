import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/glass/app_glass_controls.dart';
import '../application/update_providers.dart';

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
    return AppGlassButton.icon(
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
