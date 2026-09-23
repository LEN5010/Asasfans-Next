import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../handoff/presentation/return_entry_tile.dart';
import '../../../shared/theme/app_icons.dart';
import '../../../shared/widgets/app_controls.dart';
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
                AppButton(
                  onPressed: state.loading || state.saving
                      ? null
                      : controller.reload,
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        if (state.ready) ...[
          const ListTile(leading: Icon(AppIcons.appearance), title: Text('主题')),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: AppSegments<AppAppearance>(
              values: AppAppearance.values,
              labelOf: _appearance,
              selected: state.values.appearance,
              onChanged: state.canEdit ? controller.setAppearance : null,
            ),
          ),
          const Divider(height: 1, indent: 56),
          const ListTile(leading: Icon(AppIcons.material), title: Text('界面材质')),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: AppSegments<AppMaterial>(
              values: AppMaterial.values,
              labelOf: _material,
              selected: state.values.material,
              onChanged: state.canEdit ? controller.setMaterial : null,
            ),
          ),
          const Divider(height: 1, indent: 56),
          for (final section in const [
            HomeSection.calendar,
            HomeSection.history,
            HomeSection.clips,
            HomeSection.fanart,
          ])
            ListTile(
              title: Text(_section(section)),
              onTap: state.canEdit
                  ? () => controller.setHomeSection(
                      section,
                      !state.values.shows(section),
                    )
                  : null,
              trailing: AppSwitch(
                label: _section(section),
                value: state.values.shows(section),
                onChanged: state.canEdit
                    ? (visible) => controller.setHomeSection(section, visible)
                    : null,
              ),
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
