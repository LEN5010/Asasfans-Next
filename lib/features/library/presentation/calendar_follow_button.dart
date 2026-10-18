import '../../../core/time/local_date_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_controls.dart';
import '../../../app/providers.dart';
import '../../calendar/application/calendar_reminders.dart';
import '../../calendar/domain/calendar_event.dart';
import '../application/library_providers.dart';
import '../domain/library_models.dart';
import 'library_common.dart';

class CalendarFollowButton extends ConsumerStatefulWidget {
  const CalendarFollowButton({
    required this.event,
    this.source,
    this.iconOnly = false,
    super.key,
  });
  final CalendarEvent event;
  final Uri? source;
  final bool iconOnly;
  @override
  ConsumerState<CalendarFollowButton> createState() =>
      _CalendarFollowButtonState();
}

class _CalendarFollowButtonState extends ConsumerState<CalendarFollowButton> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    if (widget.event.hasEnded(ref.watch(currentTimeProvider)())) {
      return const SizedBox.shrink();
    }
    final key = CalendarFollowKey(
      source: widget.source ?? ref.watch(appEnvironmentProvider).calendarUrl,
      uid: widget.event.uid,
      recurrenceId: widget.event.recurrenceId,
    );
    final provider = isFollowingCalendarProvider(key);
    final state = ref.watch(provider);
    final starred = state.valueOrNull ?? false;
    final label = state.hasError
        ? '重试星标状态'
        : starred
        ? '取消星标'
        : '星标这场';
    final onPressed = _busy || state.isLoading
        ? null
        : state.hasError
        ? () => ref.invalidate(provider)
        : () async {
            setState(() => _busy = true);
            try {
              final repository = ref.read(libraryRepositoryProvider);
              if (starred) {
                await repository.unfollowCalendar(key);
              } else {
                await repository.followCalendar(key, widget.event);
                final reminders = ref.read(calendarReminderControllerProvider);
                if (reminders.preferences.enabled && !reminders.permission) {
                  await ref
                      .read(calendarReminderControllerProvider.notifier)
                      .requestPermission();
                }
              }
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(libraryError(error))));
              }
            } finally {
              if (mounted) setState(() => _busy = false);
            }
          };
    final icon = Icon(
      state.hasError
          ? Icons.refresh
          : starred
          ? Icons.star_rounded
          : Icons.star_outline_rounded,
      color: starred ? Theme.of(context).colorScheme.primary : null,
    );
    return widget.iconOnly
        ? AppButton.icon(tooltip: label, onPressed: onPressed, icon: icon)
        : AppButton.withIcon(
            onPressed: onPressed,
            icon: icon,
            label: Text(starred ? '已星标' : '星标这场'),
          );
  }
}
