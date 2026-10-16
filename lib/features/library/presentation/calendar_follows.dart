import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_page_bar.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/member_tone.dart';
import '../../../core/time/calendar_time.dart';
import '../../../core/time/shanghai_date_provider.dart';
import '../../calendar/application/calendar_follow_selection.dart';
import '../../calendar/application/calendar_providers.dart';
import '../../calendar/application/calendar_reminders.dart';
import '../../calendar/domain/event_classifier.dart';
import '../../calendar/domain/calendar_agenda.dart';
import '../../calendar/presentation/calendar_event_widgets.dart';
import '../application/library_pager.dart';
import '../application/library_providers.dart';
import '../domain/library_models.dart';
import 'calendar_follow_button.dart';
import 'library_common.dart';
import 'library_paged_list.dart';

class CalendarFollowsPage extends ConsumerStatefulWidget {
  const CalendarFollowsPage({super.key});
  @override
  ConsumerState<CalendarFollowsPage> createState() =>
      _CalendarFollowsPageState();
}

class _CalendarFollowsPageState extends ConsumerState<CalendarFollowsPage> {
  bool _refreshing = false;
  final _changingMembers = <String>{};

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final day = ref.read(shanghaiDateProvider);
    try {
      await ref.read(refreshCalendarProvider)(
        DateTime.utc(day.year, day.month),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('日历刷新失败')));
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _member(String member, bool followed) async {
    setState(() => _changingMembers.add(member));
    try {
      final saved = await libraryAction(
        context,
        () => setCalendarMemberFollow(ref, member, followed),
      );
      if (saved && followed && mounted) {
        final reminders = ref.read(calendarReminderControllerProvider);
        if (reminders.preferences.enabled && !reminders.permission) {
          await ref
              .read(calendarReminderControllerProvider.notifier)
              .requestPermission();
        }
      }
    } finally {
      if (mounted) setState(() => _changingMembers.remove(member));
    }
  }

  @override
  Widget build(BuildContext context) {
    final follows = ref.watch(calendarFollowSelectionProvider);
    final state = ref.watch(calendarFollowsProvider);
    final now = ref.watch(currentTimeProvider)();
    bool ended(CalendarFollow follow) => follow.event.allDay
        ? !CalendarTime.dayOf(now).isBefore(follow.event.end)
        : !now.isBefore(follow.event.end);
    final items = [...state.items]
      ..sort((a, b) {
        final aEnded = ended(a), bEnded = ended(b);
        if (aEnded != bEnded) return aEnded ? 1 : -1;
        final time = a.event.start.compareTo(b.event.start);
        return aEnded ? -time : time;
      });
    final firstUpcoming = items.where((item) => !ended(item)).firstOrNull;
    final firstEnded = items.where(ended).firstOrNull;
    final display = LibraryListState<CalendarFollow>(
      items: items,
      next: state.next,
      loading: state.loading,
      ready: state.ready,
      failure: state.failure,
      epoch: state.epoch,
    );
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppPageBar(
        title: const Text('关注日程'),
        actions: [
          AppButton.icon(
            tooltip: '刷新当前日历',
            onPressed: _refreshing ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: LibraryBody(
        child: LibraryPagedList<CalendarFollow>(
          state: display,
          pager: ref.read(calendarFollowsProvider.notifier),
          empty: '还没有星标场次',
          header: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('成员关注', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (follows.hasError) ...[
                  Text(libraryError(follows.error!)),
                  AppButton(
                    onPressed: () =>
                        ref.invalidate(calendarFollowSelectionProvider),
                    child: const Text('重试'),
                  ),
                ] else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final member in EventClassifier.memberAliases.keys)
                        Builder(
                          builder: (context) {
                            final tone = MemberTone.of(
                              member,
                              Theme.of(context).brightness,
                            );
                            final selected =
                                follows.valueOrNull?.members.contains(member) ??
                                false;
                            return AppChoice(
                              avatar: CircleAvatar(
                                radius: 13,
                                backgroundColor: tone.wash,
                                child: Text(
                                  member == 'A-SOUL'
                                      ? 'A'
                                      : member.substring(0, 1),
                                  style: TextStyle(
                                    color: tone.text,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              label: Text(member),
                              selected: selected,
                              onSelected:
                                  follows.hasValue &&
                                      !_changingMembers.contains(member)
                                  ? (value) => _member(member, value)
                                  : null,
                            );
                          },
                        ),
                    ],
                  ),
                const SizedBox(height: 24),
                Text('星标场次', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          itemBuilder: (context, entry) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (entry == firstUpcoming || entry == firstEnded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: Text(
                    ended(entry) ? '已结束' : '即将开始',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: Text(
                        entry.event.title.isEmpty ? '未命名安排' : entry.event.title,
                        style: TextStyle(
                          decoration: entry.event.isCancelled
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      subtitle: Text(
                        '${CalendarAgenda.range(entry.event)}${entry.event.isCancelled ? '\n已取消' : ''}',
                      ),
                      onTap: () => showCalendarEvent(
                        context,
                        entry.event,
                        source: entry.key.source,
                      ),
                    ),
                  ),
                  CalendarFollowButton(
                    event: entry.event,
                    source: entry.key.source,
                    iconOnly: true,
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
