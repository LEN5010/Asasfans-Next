import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/return_entry_service.dart';
import '../../../shared/widgets/glass/app_glass_controls.dart';
import '../application/handoff_providers.dart';

/// The opt-in for the floating return entry.
///
/// Shown only where the platform actually has one. The plan is explicit that
/// iOS must not display a switch for an Android capability that is not coming:
/// an unsupported platform renders nothing here rather than a disabled control
/// implying it is on the way.
///
/// The copy states the limit the first version genuinely has — the entry stays
/// up until the user comes back or ends it, and the app cannot tell which app
/// is in front, because finding that out would mean watching what the user is
/// doing.
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
    if (capability == null) return const SizedBox.shrink();
    if (capability.block == ReturnEntryBlock.unsupported) {
      return const SizedBox.shrink();
    }
    final tooOld = capability.block == ReturnEntryBlock.osTooOld;
    return ListTile(
      title: const Text('悬浮返回入口'),
      subtitle: Text(
        tooOld
            // Not a failure and not something to fix: the rest of the app,
            // including the ordinary handoff and return, works as it does
            // everywhere else.
            ? '当前系统版本不支持悬浮入口。去 B 站看和返回继续挑选仍然可用，用系统返回或多任务切回即可'
            : '去 B 站看之后，屏幕上留一颗球，点它回到刚才的列表。'
                  '这颗球会一直显示到你点它返回或手动结束，应用不会去检测你当前在用哪个程序',
      ),
      trailing: AppGlassSwitch(
        label: '悬浮返回入口',
        value: controller.enabled,
        onChanged: tooOld
            ? null
            : (value) async {
                final controller = ref.read(returnEntryControllerProvider);
                if (!value) {
                  controller.disable();
                  return;
                }
                final granted = await controller.enable();
                if (granted || !context.mounted) return;
                // enable() returns false both for a refusal and for a permission
                // request still in flight; the message says what is true in
                // either case without claiming the request failed.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('需要在系统设置里允许显示悬浮窗，授权后回到这里再打开一次')),
                );
              },
      ),
    );
  }
}
