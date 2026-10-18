import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/app_page_bar.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../content/presentation/content_images.dart';
import '../../../core/time/local_date_provider.dart';
import '../../calendar/application/calendar_follow_selection.dart';
import '../../calendar/application/calendar_providers.dart';
import '../../calendar/application/calendar_reminders.dart';
import '../../calendar/domain/event_classifier.dart';
import '../../calendar/domain/calendar_agenda.dart';
import '../../calendar/presentation/calendar_event_widgets.dart';
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
    final day = ref.read(localDateProvider);
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
    final theme = Theme.of(context);
    final follows = ref.watch(calendarFollowSelectionProvider);
    final upcoming = ref.watch(followedUpcomingProvider);
    final now = ref.watch(currentTimeProvider)();
    final today = ref.watch(localDateProvider);
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(text, style: theme.textTheme.titleMedium),
    );
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
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
          state: ref.watch(calendarFollowsProvider),
          pager: ref.read(calendarFollowsProvider.notifier),
          empty: '还没有星标场次',
          header: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('成员关注', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                if (follows.hasError) ...[
                  Text(libraryError(follows.error!)),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: AppButton(
                      onPressed: () =>
                          ref.invalidate(calendarFollowSelectionProvider),
                      child: const Text('重试'),
                    ),
                  ),
                ] else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final member in EventClassifier.memberAliases.keys)
                        MemberChoiceButton(
                          label: member,
                          members: [member],
                          selected:
                              follows.valueOrNull?.members.contains(member) ??
                              false,
                          onPressed:
                              follows.hasValue &&
                                  !_changingMembers.contains(member)
                              ? () => _member(
                                  member,
                                  !follows.requireValue.members.contains(
                                    member,
                                  ),
                                )
                              : null,
                        ),
                    ],
                  ),
                // What all of it adds up to: the members' events and the
                // starred ones, as the calendar draws them.
                heading('接下来 30 天'),
                switch (upcoming) {
                  AsyncValue(valueOrNull: final value?) when value.isEmpty =>
                    Text('关注的成员和星标场次接下来没有安排', style: muted),
                  AsyncValue(valueOrNull: final value?) => Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AppTokens.readingWidth,
                      ),
                      child: AppCard(
                        padding: const EdgeInsets.all(6),
                        child: Column(
                          children: [
                            for (final event in value)
                              CalendarAgendaRow(
                                event: event,
                                showDay: true,
                                today: today,
                                now: now,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  AsyncValue(hasError: true) => Row(
                    children: [
                      Expanded(child: Text('日历暂时读取失败', style: muted)),
                      AppButton(
                        onPressed: () =>
                            ref.invalidate(followedUpcomingProvider),
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                  _ => const LinearProgressIndicator(),
                },
                heading('全部星标'),
              ],
            ),
          ),
          itemBuilder: (context, entry) => Row(
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
        ),
      ),
    );
  }
}
