import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../handoff/presentation/return_entry_tile.dart';
import '../../../shared/theme/app_icons.dart';
import '../application/preferences_controller.dart';
import '../domain/app_preferences.dart';

class PreferencesControls extends ConsumerWidget {
  const PreferencesControls({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(preferencesControllerProvider);
    final controller = ref.read(preferencesControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.loading || state.saving)
          const LinearProgressIndicator(minHeight: 2),
        if (state.failure != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.failure!.message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                TextButton(
                  onPressed: state.loading || state.saving
                      ? null
                      : controller.reload,
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        if (state.ready) ...[
          ListTile(
            leading: const Icon(AppIcons.appearance),
            title: const Text('主题'),
            subtitle: Text(_appearance(state.values.appearance)),
            trailing: const Icon(Icons.chevron_right),
            enabled: state.canEdit,
            onTap: state.canEdit
                ? () async {
                    final choice = await showDialog<AppAppearance>(
                      context: context,
                      builder: (context) => SimpleDialog(
                        title: const Text('主题'),
                        children: [
                          for (final value in AppAppearance.values)
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(context, value),
                              child: Row(
                                children: [
                                  Icon(
                                    value == state.values.appearance
                                        ? Icons.check_circle
                                        : Icons.circle_outlined,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(_appearance(value))),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                    if (choice != null && context.mounted) {
                      await controller.setAppearance(choice);
                    }
                  }
                : null,
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(AppIcons.material),
            title: const Text('界面材质'),
            subtitle: Text(_material(state.values.material)),
            trailing: const Icon(Icons.chevron_right),
            enabled: state.canEdit,
            onTap: !state.canEdit
                ? null
                : () async {
                    final choice = await showDialog<AppMaterial>(
                      context: context,
                      builder: (context) => SimpleDialog(
                        title: const Text('界面材质'),
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
                            child: Text('系统无障碍设置优先；不支持时自动使用清晰模式。'),
                          ),
                          for (final value in AppMaterial.values)
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(context, value),
                              child: Row(
                                children: [
                                  Icon(
                                    value == state.values.material
                                        ? Icons.check_circle
                                        : Icons.circle_outlined,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(_material(value))),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                    if (choice != null && context.mounted) {
                      await controller.setMaterial(choice);
                    }
                  },
          ),
          const Divider(height: 1, indent: 56),
          for (final section in HomeSection.values)
            SwitchListTile.adaptive(
              title: Text(_section(section)),
              value: state.values.shows(section),
              onChanged: state.canEdit
                  ? (visible) => controller.setHomeSection(section, visible)
                  : null,
            ),
          // Device-local: the permission and the running service belong to this
          // installation, so the choice is not something a backup carries to
          // another phone.
          const ReturnEntryTile(),
        ],
      ],
    );
  }

  static String _material(AppMaterial value) => switch (value) {
    AppMaterial.liquid => '液态玻璃',
    AppMaterial.clear => '清晰模式',
  };

  static String _appearance(AppAppearance value) => switch (value) {
    AppAppearance.system => '跟随系统',
    AppAppearance.light => '浅色',
    AppAppearance.dark => '深色',
  };
  static String _section(HomeSection value) => switch (value) {
    HomeSection.calendar => '首页日程',
    HomeSection.fanart => '首页二创',
    HomeSection.clips => '首页切片',
    HomeSection.history => '历史上的今天',
  };
}
