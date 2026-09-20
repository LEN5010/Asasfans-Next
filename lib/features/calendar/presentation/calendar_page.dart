import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/network/api_failure.dart';
import '../application/calendar_providers.dart';
import '../domain/calendar_event.dart';
import '../domain/event_classifier.dart';

enum CalendarFilter {
  all('全部'),
  live('直播'),
  other('其他活动');

  const CalendarFilter(this.label);
  final String label;
}

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  CalendarFilter _filter = CalendarFilter.all;
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(visibleMonthProvider);
    final snapshot = ref.watch(monthEventsProvider(month));
    final selected = _selectedDay ?? shanghaiDayOf(shanghaiNow(), allDay: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('日历'),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(monthEventsProvider(month)),
          ),
        ],
      ),
      body: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _CalendarError(
          message: error is ApiFailure ? error.message : '日历加载失败',
          onRetry: () => ref.invalidate(monthEventsProvider(month)),
        ),
        data: (data) {
          final byDay = _groupByDay(data.events);
          return Column(
            children: [
              _MonthHeader(
                month: month,
                onChange: (delta) => setState(() {
                  ref.read(visibleMonthProvider.notifier).state = DateTime.utc(
                    month.year,
                    month.month + delta,
                  );
                  _selectedDay = null;
                }),
              ),
              _FilterRow(
                value: _filter,
                onChanged: (value) => setState(() => _filter = value),
              ),
              if (data.fromCache) _StaleBanner(fetchedAt: data.fetchedAt),
              _MonthGrid(
                month: month,
                selected: selected,
                byDay: byDay,
                filter: _filter,
                onSelect: (day) => setState(() => _selectedDay = day),
              ),
              const Divider(height: 1),
              Expanded(
                child: _Agenda(
                  day: selected,
                  events: _visible(byDay[selected] ?? const [], _filter),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// An event is listed on every Shanghai day it covers, so a broadcast that
  /// runs past midnight appears on both days rather than only its start day.
  static Map<DateTime, List<CalendarEvent>> _groupByDay(
    List<CalendarEvent> events,
  ) {
    final byDay = <DateTime, List<CalendarEvent>>{};
    for (final event in events) {
      var day = shanghaiDayOf(event.start, allDay: event.allDay);
      final last = shanghaiDayOf(
        event.allDay
            // An exclusive all-day end does not occupy its final date.
            ? event.end.subtract(const Duration(days: 1))
            : event.end.subtract(const Duration(milliseconds: 1)),
        allDay: event.allDay,
      );
      while (!day.isAfter(last)) {
        byDay.putIfAbsent(day, () => []).add(event);
        day = day.add(const Duration(days: 1));
      }
    }
    for (final list in byDay.values) {
      list.sort((a, b) => a.start.compareTo(b.start));
    }
    return byDay;
  }

  static List<CalendarEvent> _visible(
    List<CalendarEvent> events,
    CalendarFilter filter,
  ) => switch (filter) {
    CalendarFilter.all => events,
    CalendarFilter.live =>
      events
          .where((e) => EventClassifier.classify(e) == EventKind.live)
          .toList(),
    CalendarFilter.other =>
      events
          .where((e) => EventClassifier.classify(e) == EventKind.other)
          .toList(),
  };
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.month, required this.onChange});
  final DateTime month;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: '上个月',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChange(-1),
        ),
        Text(
          '${month.year} 年 ${month.month} 月',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        IconButton(
          tooltip: '下个月',
          icon: const Icon(Icons.chevron_right),
          onPressed: () => onChange(1),
        ),
      ],
    ),
  );
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.value, required this.onChanged});
  final CalendarFilter value;
  final ValueChanged<CalendarFilter> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Wrap(
      spacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final filter in CalendarFilter.values)
          ChoiceChip(
            label: Text(filter.label),
            selected: value == filter,
            onSelected: (_) => onChanged(filter),
          ),
      ],
    ),
  );
}

/// Says plainly that the list is not current instead of implying it is.
class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.fetchedAt});
  final DateTime fetchedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = fetchedAt.toUtc().add(const Duration(hours: 8));
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        '显示的是缓存内容，上次同步 '
        '${local.month}-${local.day} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}',
        style: theme.textTheme.labelSmall,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.byDay,
    required this.filter,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime selected;
  final Map<DateTime, List<CalendarEvent>> byDay;
  final CalendarFilter filter;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = DateTime.utc(month.year, month.month);
    // Weeks start on Monday, matching the published schedule.
    final leading = first.weekday - 1;
    final days = DateTime.utc(month.year, month.month + 1, 0).day;
    final cells = ((leading + days) / 7).ceil() * 7;
    final today = shanghaiDayOf(shanghaiNow(), allDay: true);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Row(
            children: [
              for (final label in ['一', '二', '三', '四', '五', '六', '日'])
                Expanded(
                  child: Center(
                    child: Text(label, style: theme.textTheme.labelSmall),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.1,
            ),
            itemCount: cells,
            itemBuilder: (context, index) {
              final dayNumber = index - leading + 1;
              if (dayNumber < 1 || dayNumber > days) {
                return const SizedBox.shrink();
              }
              final day = DateTime.utc(month.year, month.month, dayNumber);
              final events = _CalendarPageState._visible(
                byDay[day] ?? const [],
                filter,
              );
              return _DayCell(
                day: day,
                count: events.length,
                isSelected: day == selected,
                isToday: day == today,
                onTap: () => onSelect(day),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.count,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  final DateTime day;
  final int count;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primaryContainer : null,
          border: isToday
              ? Border.all(color: theme.colorScheme.primary, width: 1.5)
              : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${day.day}', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 3),
            SizedBox(
              height: 6,
              child: count == 0
                  ? null
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < (count > 3 ? 3 : count); i++)
                          Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Agenda extends StatelessWidget {
  const _Agenda({required this.day, required this.events});
  final DateTime day;
  final List<CalendarEvent> events;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (events.isEmpty) {
      return Center(
        child: Text(
          '${day.month} 月 ${day.day} 日没有安排',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: events.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _EventTile(event: events[index]),
    );
  }
}

class _EventTile extends ConsumerWidget {
  const _EventTile({required this.event});
  final CalendarEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final members = EventClassifier.members(event);
    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: event.sourceUrl == null
            ? null
            : () =>
                  ref.read(externalLinkServiceProvider).open(event.sourceUrl!),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 56,
                child: Text(
                  event.allDay ? '全天' : _time(event.start),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title.isEmpty ? '未命名安排' : event.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        decoration: event.isCancelled
                            ? TextDecoration.lineThrough
                            : null,
                        color: event.isCancelled
                            ? theme.colorScheme.outline
                            : null,
                      ),
                    ),
                    if (event.isCancelled)
                      Text('已取消', style: theme.textTheme.labelSmall),
                    if (members.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final member in members)
                            Chip(
                              label: Text(member),
                              visualDensity: VisualDensity.compact,
                              labelStyle: theme.textTheme.labelSmall,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _time(DateTime utc) {
    final local = utc.toUtc().add(const Duration(hours: 8));
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _CalendarError extends StatelessWidget {
  const _CalendarError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.event_busy_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(height: 16),
        Text(message),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: const Text('重试')),
      ],
    ),
  );
}
