import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/return_entry_service.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/member_tone.dart';
import '../application/handoff_providers.dart';

/// The opt-in for the floating return entry.
///
/// Shown only where the platform actually has one. The plan is explicit that
/// iOS must not display a switch for an Android capability that is not coming:
/// an unsupported platform renders nothing here rather than a disabled control
/// implying it is on the way.
///
/// A row of the Mine page rather than a buried setting: users who never find
/// it cannot get back from Bilibili with one tap.
class ReturnEntryTile extends ConsumerStatefulWidget {
  const ReturnEntryTile({super.key});

  @override
  ConsumerState<ReturnEntryTile> createState() => _ReturnEntryTileState();
}

class _ReturnEntryTileState extends ConsumerState<ReturnEntryTile> {
  @override
  void initState() {
    super.initState();
    // Asked once on open. The permission can be revoked from system settings
    // while the app is away, so the stored preference is never trusted as
    // proof that the entry can still be shown.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(returnEntryControllerProvider).refreshCapability();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(returnEntryControllerProvider);
    final capability = controller.capability;
    if (capability?.block == ReturnEntryBlock.unsupported) {
      return const SizedBox.shrink();
    }
    final tooOld = capability?.block == ReturnEntryBlock.osTooOld;
    Future<void> toggle(bool value) async {
      if (!value) {
        controller.disable();
        return;
      }
      final granted = await controller.enable();
      if (granted || !context.mounted) return;
      // enable() returns false both for a refusal and for a permission request
      // still in flight; the permission screen's return settles the switch.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请在系统设置里允许显示在其他应用上层，回来后会自动打开')),
      );
    }

    final theme = Theme.of(context);
    return InkWell(
      onTap: tooOld ? null : () => toggle(!controller.enabled),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 54),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              const ToneBadge(icon: Icons.u_turn_left, member: '贝拉'),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('悬浮返回球', style: theme.textTheme.bodyLarge),
                    Text(
                      tooOld ? '需要 Android 8.0 以上' : '看 B 站时点球回到刚才的列表',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppSwitch(
                label: '悬浮返回球',
                value: controller.enabled,
                onChanged: tooOld ? null : toggle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
