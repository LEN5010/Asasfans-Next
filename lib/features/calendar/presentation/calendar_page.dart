import 'package:flutter/material.dart';

import '../../../shared/widgets/app_controls.dart';
import '../../../app/theme/app_theme.dart';

import '../../../shared/widgets/app_page_bar.dart';
import '../../../shared/widgets/horizontal_choices.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/time/calendar_time.dart';
import '../../../core/time/shanghai_date_provider.dart';
import '../../../shared/widgets/retry_button.dart';
import '../application/calendar_providers.dart';
import '../domain/calendar_agenda.dart';
import '../domain/calendar_event.dart';
import '../domain/event_classifier.dart';
import 'calendar_event_widgets.dart';

export '../domain/calendar_agenda.dart' show CalendarFilter;

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});
  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  CalendarFilter _filter = CalendarFilter.all;
  Set<String> _members = {};
  bool _week = false;
  bool _monthExpanded = false;
  bool _refreshing = false;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (mounted) ref.invalidate(monthEventsProvider);
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _select(DateTime day) {
    ref.read(selectedCalendarDayProvider.notifier).state = day;
    ref.read(visibleMonthProvider.notifier).state = DateTime.utc(
      day.year,
      day.month,
    );
  }

  void _today() {
    final day = ref.read(shanghaiDateProvider);
    ref.read(selectedCalendarDayProvider.notifier).state = null;
    ref.read(visibleMonthProvider.notifier).state = DateTime.utc(
      day.year,
      day.month,
    );
  }

  Future<void> _refresh(DateTime month) async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await ref.read(refreshCalendarProvider)(month);
    } on ApiFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(visibleMonthProvider);
    final today = ref.watch(shanghaiDateProvider);
    final selected = CalendarTime.selectDayInMonth(
      month,
      ref.watch(selectedCalendarDayProvider) ?? today,
    );
    final snapshot = ref.watch(monthEventsProvider(month));
    ref.listen(shanghaiDateProvider, (previous, next) {
      if (previous != null &&
          ref.read(selectedCalendarDayProvider) == null &&
          month.year == previous.year &&
          month.month == previous.month) {
        ref.read(visibleMonthProvider.notifier).state = DateTime.utc(
          next.year,
          next.month,
        );
      }
    });
    final events = (snapshot.valueOrNull?.events ?? const <CalendarEvent>[])
        .where(
          (event) =>
              CalendarAgenda.visible(event, filter: _filter, members: _members),
        )
        .toList();
    final byDay = CalendarAgenda.group(
      events,
      from: month,
      until: DateTime.utc(month.year, month.month + 1),
    );

    Widget monthHeader({bool collapsible = false}) => _MonthHeader(
      month: month,
      expanded: _monthExpanded,
      collapsible: collapsible,
      onToggle: () => setState(() => _monthExpanded = !_monthExpanded),
      onChange: (delta) => _select(
        CalendarTime.selectDayInMonth(
          DateTime.utc(month.year, month.month + delta),
          selected,
        ),
      ),
    );
    Widget filters({required bool wide}) => _CalendarFilters(
      wide: wide,
      filter: _filter,
      members: _members,
      onFilter: (value) => setState(() => _filter = value),
      onMember: (value) => setState(
        () => _members = _members.contains(value)
            ? ({..._members}..remove(value))
            : {..._members, value},
      ),
      onReset: () => setState(() {
        _filter = CalendarFilter.all;
        _members = {};
      }),
    );
    Widget agenda({required bool scrollable}) => _Agenda(
      key: ValueKey('calendar-agenda-$scrollable'),
      day: selected,
      week: _week,
      onWeek: (value) => setState(() => _week = value),
      snapshot: snapshot,
      events: events,
      scrollable: scrollable,
      filtered: _filter != CalendarFilter.all || _members.isNotEmpty,
      onRetry: () => _refresh(month),
    );
    return Scaffold(
      extendBodyBehindAppBar: true,
      // The shell's backdrop shows through the main pages.
      backgroundColor: Colors.transparent,
      appBar: AppPageBar(
        title: const Text('日历'),
        actions: [
          AppButton.icon(
            tooltip: '回到今天',
            onPressed: _today,
            icon: const Icon(Icons.today_outlined),
          ),
          AppButton.icon(
            tooltip: '刷新',
            onPressed: _refreshing ? null : () => _refresh(month),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 880) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: (constraints.maxWidth * .32).clamp(300, 340),
                  child: ListView(
                    key: const ValueKey('calendar-sidebar'),
                    padding: pageInsets(context, horizontal: 12, top: 0),
                    children: [
                      monthHeader(),
                      _MonthGrid(
                        month: month,
                        selected: selected,
                        today: today,
                        byDay: byDay,
                        onSelect: _select,
                      ),
                      const Divider(height: 28),
                      filters(wide: true),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: agenda(scrollable: true)),
              ],
            );
          }
          return ListView(
            key: const ValueKey('calendar-compact'),
            padding: pageInsets(context, horizontal: 0, top: 0),
            children: [
              monthHeader(collapsible: true),
              if (_monthExpanded)
                _MonthGrid(
                  month: month,
                  selected: selected,
                  today: today,
                  byDay: byDay,
                  onSelect: _select,
                )
              else
                _WeekStrip(
                  selected: selected,
                  today: today,
                  events: events,
                  onSelect: _select,
                ),
              const SizedBox(height: 8),
              filters(wide: false),
              agenda(scrollable: false),
            ],
          );
        },
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onChange,
    required this.onToggle,
    required this.expanded,
    this.collapsible = false,
  });
  final DateTime month;
  final ValueChanged<int> onChange;
  final VoidCallback onToggle;
  final bool expanded;
  final bool collapsible;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Row(
      children: [
        AppButton.icon(
          tooltip: '上个月',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChange(-1),
        ),
        Expanded(
          child: Text(
            '${month.year} 年 ${month.month} 月',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        AppButton.icon(
          tooltip: '下个月',
          icon: const Icon(Icons.chevron_right),
          onPressed: () => onChange(1),
        ),
        if (collapsible)
          AppButton.icon(
            tooltip: expanded ? '收起月历' : '展开月历',
            onPressed: onToggle,
            icon: Icon(
              expanded ? Icons.expand_less : Icons.calendar_view_month,
            ),
          ),
      ],
    ),
  );
}

class _CalendarFilters extends StatelessWidget {
  const _CalendarFilters({
    required this.wide,
    required this.filter,
    required this.members,
    required this.onFilter,
    required this.onMember,
    required this.onReset,
  });
  final bool wide;
  final CalendarFilter filter;
  final Set<String> members;
  final ValueChanged<CalendarFilter> onFilter;
  final ValueChanged<String> onMember;
  final VoidCallback onReset;
  @override
  Widget build(BuildContext context) {
    final types = [
      for (final value in CalendarFilter.values)
        AppChoice(
          label: Text(value.label),
          selected: value == filter,
          onSelected: (_) => onFilter(value),
        ),
    ];
    final roles = [
      for (final name in EventClassifier.memberAliases.keys)
        AppChoice(
          avatar: CircleAvatar(
            backgroundColor: AppTheme.memberColors[name],
            radius: 6,
          ),
          label: Text(name),
          selected: members.contains(name),
          onSelected: (_) => onMember(name),
        ),
    ];
    Widget row(List<Widget> children) => wide
        ? Wrap(spacing: 6, runSpacing: 6, children: children)
        : HorizontalChoices(children: children);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(types),
          const SizedBox(height: 8),
          if (wide) ...[
            Text('成员', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
          ],
          row(roles),
          if (filter != CalendarFilter.all || members.isNotEmpty)
            AppButton(onPressed: onReset, child: const Text('重置筛选')),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.today,
    required this.byDay,
    required this.onSelect,
  });
  final DateTime month;
  final DateTime selected;
  final DateTime today;
  final Map<DateTime, List<CalendarEvent>> byDay;
  final ValueChanged<DateTime> onSelect;
  @override
  Widget build(BuildContext context) {
    final first = DateTime.utc(month.year, month.month);
    final leading = first.weekday - 1;
    final days = DateTime.utc(month.year, month.month + 1, 0).day;
    final cells = ((leading + days) / 7).ceil() * 7;
    final height = _cellHeight(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          const _Weekdays(),
          const SizedBox(height: 4),
          SizedBox(
            height: cells / 7 * height,
            child: GridView.builder(
              primary: false,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: height,
              ),
              itemCount: cells,
              itemBuilder: (_, index) {
                final number = index - leading + 1;
                if (number < 1 || number > days) return const SizedBox.shrink();
                final day = DateTime.utc(month.year, month.month, number);
                return _DayCell(
                  day: day,
                  events: byDay[day] ?? const [],
                  isSelected: day == selected,
                  isToday: day == today,
                  onTap: () => onSelect(day),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.selected,
    required this.today,
    required this.events,
    required this.onSelect,
  });
  final DateTime selected;
  final DateTime today;
  final List<CalendarEvent> events;
  final ValueChanged<DateTime> onSelect;
  @override
  Widget build(BuildContext context) {
    final monday = CalendarAgenda.weekStart(selected);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          const _Weekdays(),
          const SizedBox(height: 4),
          SizedBox(
            height: _cellHeight(context),
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: _DayCell(
                      day: monday.add(Duration(days: i)),
                      events: CalendarAgenda.onDay(
                        events,
                        monday.add(Duration(days: i)),
                      ),
                      isSelected: selected == monday.add(Duration(days: i)),
                      isToday: today == monday.add(Duration(days: i)),
                      onTap: () => onSelect(monday.add(Duration(days: i))),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

double _cellHeight(BuildContext context) =>
    (MediaQuery.textScalerOf(context).scale(14) * 1.4 + 16).clamp(
      44,
      double.infinity,
    );

class _Weekdays extends StatelessWidget {
  const _Weekdays();
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final label in const ['一', '二', '三', '四', '五', '六', '日'])
        Expanded(
          child: Center(
            child: Text(label, style: Theme.of(context).textTheme.labelSmall),
          ),
        ),
    ],
  );
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.events,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });
  final DateTime day;
  final List<CalendarEvent> events;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final count = events.length;
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${day.year} 年 ${CalendarAgenda.date(day)}，$count 项安排',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSelected ? colors.secondaryContainer : null,
            border: isToday
                ? Border.all(color: colors.primary, width: 1.5)
                : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${day.day}',
                  maxLines: 1,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.4),
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: 6,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // One dot per event in its member's colour; the selected
                    // day's pink fill would swallow a pink dot, so it rings.
                    for (final event in events.take(3))
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: event.isCancelled
                              ? colors.outlineVariant
                              : calendarEventColor(event),
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 1)
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Agenda extends StatelessWidget {
  const _Agenda({
    required this.day,
    required this.week,
    required this.onWeek,
    required this.snapshot,
    required this.events,
    required this.filtered,
    required this.onRetry,
    required this.scrollable,
    super.key,
  });
  final DateTime day;
  final bool week;
  final ValueChanged<bool> onWeek;
  final AsyncValue<CalendarSnapshot> snapshot;
  final List<CalendarEvent> events;
  final bool filtered;
  final VoidCallback onRetry;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final from = week ? CalendarAgenda.weekStart(day) : day;
    final until = from.add(Duration(days: week ? 7 : 1));
    final children = <Widget>[
      Align(
        alignment: Alignment.centerLeft,
        child: SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: false, label: Text('当天')),
            ButtonSegment(value: true, label: Text('周议程')),
          ],
          selected: {week},
          onSelectionChanged: (values) => onWeek(values.single),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        week
            ? '${CalendarAgenda.date(from)} — ${CalendarAgenda.date(until.subtract(const Duration(days: 1)))}'
            : CalendarAgenda.date(day),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 12),
      snapshot.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Column(
          children: [
            Text(error is ApiFailure ? error.message : '日历加载失败'),
            const SizedBox(height: 12),
            RetryButton(
              failure: error is ApiFailure ? error : null,
              onRetry: onRetry,
              filled: true,
            ),
          ],
        ),
        data: (data) {
          final grouped = CalendarAgenda.group(
            events,
            from: from,
            until: until,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (data.isStale) CalendarStaleBanner(fetchedAt: data.fetchedAt),
              if (data.offlineCacheUnavailable)
                const CalendarCacheFailureBanner(),
              if (data.followSyncUnavailable) const CalendarFollowSyncBanner(),
              if (grouped.values.every((list) => list.isEmpty))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    '${week ? '这一周' : CalendarAgenda.date(day)}${filtered ? '没有符合条件的安排' : '没有安排'}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              for (final entry in grouped.entries.where(
                (entry) => entry.value.isNotEmpty,
              )) ...[
                if (week)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
                    child: Text(
                      CalendarAgenda.date(entry.key),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                for (final event in entry.value)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: CalendarEventTile(event: event, day: entry.key),
                  ),
              ],
            ],
          );
        },
      ),
    ];
    return ListView(
      padding: scrollable
          ? pageInsets(context, top: 12)
          : const EdgeInsets.fromLTRB(16, 12, 16, 0),
      shrinkWrap: !scrollable,
      primary: false,
      physics: scrollable ? null : const NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}
