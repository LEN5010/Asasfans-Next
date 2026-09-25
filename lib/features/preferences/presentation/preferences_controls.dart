import '../../../shared/widgets/glass/app_glass_scope.dart';
import '../../../shared/widgets/glass/glass_policy.dart';
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
          const ListTile(
            leading: Icon(AppIcons.material),
            title: Text('界面材质与性能'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: AppSegments<GlassChoice>(
              values: GlassChoice.values,
              labelOf: _glass,
              selected: state.values.glass,
              onChanged: state.canEdit ? controller.setGlass : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              effectiveGlassLabel(AppGlassScope.of(context)),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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

  static String _glass(GlassChoice value) => switch (value) {
    GlassChoice.smooth => '流畅优先',
    GlassChoice.auto => '自动',
    GlassChoice.visual => '视觉优先',
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

/// States what is rendered now and why, so a choice that the system or the
/// renderer overrides never looks as if it silently failed.
String effectiveGlassLabel(GlassPolicy policy) {
  final tier = switch (policy.tier) {
    GlassTier.solid => '实底界面',
    GlassTier.standard => '标准玻璃',
    GlassTier.premium => '精细玻璃',
  };
  final reason = switch (policy.fallback) {
    GlassFallback.none => null,
    GlassFallback.userChoice => '流畅优先，不采样背景',
    GlassFallback.reducedTransparency => '系统已开启降低透明度',
    GlassFallback.highContrast => '系统已开启高对比度',
    GlassFallback.unsupported => '此设备的渲染器不支持玻璃着色器',
    GlassFallback.failed => '玻璃加载失败，本次运行保持实底',
    GlassFallback.preparing || GlassFallback.transparencyPending => '玻璃准备中',
    GlassFallback.inactive => '应用在后台',
    GlassFallback.nativeContent => '当前内容不支持玻璃',
  };
  return reason == null ? '当前：$tier' : '当前：$tier（$reason）';
}
