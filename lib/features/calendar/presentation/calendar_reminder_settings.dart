import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/app_controls.dart';
import '../application/calendar_reminders.dart';
import 'calendar_event_widgets.dart';

class CalendarReminderSettings extends ConsumerWidget {
  const CalendarReminderSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calendarReminderControllerProvider);
    final controller = ref.read(calendarReminderControllerProvider.notifier);
    final editable = state.ready && !state.busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: const Text('开播提醒'),
          onTap: editable
              ? () => controller.setPreferences(
                  enabled: !state.preferences.enabled,
                )
              : null,
          trailing: AppSwitch(
            label: '开播提醒',
            value: state.preferences.enabled,
            onChanged: editable
                ? (value) => controller.setPreferences(enabled: value)
                : null,
          ),
        ),
        if (state.preferences.enabled) ...[
          const ListTile(title: Text('提前多久')),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: AppSegments<int>(
              values: const [0, 5, 15, 30],
              labelOf: (minutes) => minutes == 0 ? '准点' : '$minutes 分钟',
              selected: state.preferences.minutes,
              onChanged: editable
                  ? (minutes) => controller.setPreferences(minutes: minutes)
                  : null,
            ),
          ),
          if (state.ready && (!state.permission || !state.exactPermission))
            ListTile(
              title: Text(!state.permission ? '通知未开启' : '精确定时权限未开启'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!state.permission)
                    AppButton(
                      onPressed: () => ref
                          .read(calendarReminderServiceProvider)
                          .openSettings(),
                      child: const Text('系统设置'),
                    ),
                  AppButton(
                    selected: true,
                    onPressed: state.busy ? null : controller.requestPermission,
                    child: const Text('开启'),
                  ),
                ],
              ),
            ),
        ],
        if (state.failure != null)
          ListTile(
            title: Text(
              state.failure!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            trailing: AppButton(
              onPressed: controller.synchronize,
              child: const Text('重试'),
            ),
          ),
      ],
    );
  }
}

/// Kept beside the root navigator so notification taps also work while a
/// detail page is already open. The shell owns startup and resume refreshes.
class CalendarReminderListener extends ConsumerWidget {
  const CalendarReminderListener({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(calendarReminderOpenProvider, (_, value) async {
      if (value == null) return;
      ref.read(calendarReminderOpenProvider.notifier).state = null;
      final room = calendarLiveRoom(value.event.sourceUrl);
      if (room != null) {
        final opened = await ref.read(externalLinkServiceProvider).open(room);
        if (opened) return;
      }
      if (context.mounted) {
        await showCalendarEvent(context, value.event, source: value.calendar);
      }
    });
    return child;
  }
}

Uri? calendarLiveRoom(Uri? uri) {
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.toLowerCase() != 'live.bilibili.com') {
    return null;
  }
  final parts = uri.pathSegments.where((part) => part.isNotEmpty).toList();
  return parts.length == 1 && RegExp(r'^\d+$').hasMatch(parts.single)
      ? uri
      : null;
}
