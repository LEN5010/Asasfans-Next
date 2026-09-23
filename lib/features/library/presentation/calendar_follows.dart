import '../../../shared/widgets/app_page_bar.dart';

import 'package:flutter/material.dart';

import '../../../shared/widgets/glass/app_glass_controls.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/calendar_time.dart';
import '../../../core/time/shanghai_date_provider.dart';
import '../../calendar/application/calendar_providers.dart';
import '../../calendar/domain/calendar_agenda.dart';
import '../../calendar/presentation/calendar_event_widgets.dart';
import '../application/library_providers.dart';
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

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: AppPageBar(
      title: const Text('关注日程'),
      actions: [
        AppGlassButton.icon(
          tooltip: '刷新当前日历',
          onPressed: _refreshing ? null : _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: LibraryBody(
      child: LibraryPagedList(
        state: ref.watch(calendarFollowsProvider),
        pager: ref.read(calendarFollowsProvider.notifier),
        empty: '还没有关注的日程',
        itemBuilder: (context, entry) {
          final event = entry.event;
          final observed = entry.observedAt == null
              ? null
              : CalendarTime.inShanghai(entry.observedAt!);
          return ListTile(
            isThreeLine: true,
            title: Text(
              event.title.isEmpty ? '未命名安排' : event.title,
              style: TextStyle(
                decoration: event.isCancelled
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            subtitle: Text(
              [
                CalendarAgenda.range(event),
                if (event.isCancelled) '已取消',
                entry.key.source.host,
                if (observed != null)
                  '更新于 ${observed.year}-${observed.month}-${observed.day} ${CalendarAgenda.time(entry.observedAt!)}',
              ].join('\n'),
            ),
            onTap: () =>
                showCalendarEvent(context, event, source: entry.key.source),
            trailing: AppGlassButton.icon(
              tooltip: '取消关注',
              icon: const Icon(Icons.star),
              onPressed: () => libraryAction(
                context,
                () => ref
                    .read(libraryRepositoryProvider)
                    .unfollowCalendar(entry.key),
              ),
            ),
          );
        },
      ),
    ),
  );
}
