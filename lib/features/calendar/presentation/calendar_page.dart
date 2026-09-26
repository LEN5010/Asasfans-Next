import 'package:flutter/material.dart';

import '../../../shared/widgets/app_controls.dart';
import '../../../app/theme/app_theme.dart';

import '../../../shared/widgets/app_page_bar.dart';
import '../../../shared/widgets/page_heading.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../../shared/widgets/horizontal_choices.dart';
import '../../../shared/widgets/query_summary.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/resume_when_visible.dart';

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

class _CalendarPageState extends ConsumerState<CalendarPage>
    with ResumeWhenVisible {
  CalendarFilter _filter = CalendarFilter.all;

  /// Whether the type and member choices are open (compact layout only).
  bool _filtersOpen = false;
  Set<String> _members = {};
  bool _week = false;
  bool _monthExpanded = false;
  bool _refreshing = false;

  // The repository's TTL, ETag/304 and single-flight decide whether this
  // touches the network; a hidden calendar need not ask at all.
  @override
  void onVisibleResume() => ref.invalidate(monthEventsProvider);

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
    final filtered = _filter != CalendarFilter.all || _members.isNotEmpty;
    void reset() => setState(() {
      _filter = CalendarFilter.all;
      _members = {};
    });
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
      onReset: reset,
    );
    Widget agenda({required bool scrollable, bool segments = true}) => _Agenda(
      key: ValueKey('calendar-agenda-$scrollable'),
      day: selected,
      week: _week,
      segments: segments,
      onWeek: (value) => setState(() => _week = value),
      snapshot: snapshot,
      events: events,
      scrollable: scrollable,
      filtered: filtered,
      onRetry: () => _refresh(month),
    );
    final heading = RootHeading(
      title: '日历',
      subtitle: '今天 ${CalendarAgenda.date(today)}',
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
    );
    final top = MediaQuery.paddingOf(context).top + 16;
    return Scaffold(
      // The shell's backdrop shows through the main pages.
      backgroundColor: Colors.transparent,
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
                    padding: EdgeInsets.fromLTRB(
                      12,
                      top,
                      12,
                      MediaQuery.paddingOf(context).bottom + 24,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 12, bottom: 12),
                        child: heading,
                      ),
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
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: agenda(scrollable: true),
                    ),
                  ),
                ),
              ],
            );
          }
          return ListView(
            key: const ValueKey('calendar-compact'),
            padding: EdgeInsets.fromLTRB(
              0,
              top,
              0,
              MediaQuery.paddingOf(context).bottom + 24,
            ),
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppTokens.gutter(constraints.maxWidth),
                ),
                child: heading,
              ),
              const SizedBox(height: 12),
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
              // One row of controls under the dates: day or week, and the
              // less used type and member choices folded behind 筛选.
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppTokens.gutter(constraints.maxWidth),
                ),
                // Large text wraps the button under the switch rather than
                // squeezing either.
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: _DayOrWeek(
                        week: _week,
                        onWeek: (value) => setState(() => _week = value),
                      ),
                    ),
                    AppButton.withIcon(
                      tooltip: _filtersOpen ? '收起筛选' : '按类型或成员筛选',
                      selected: _filtersOpen || filtered,
                      onPressed: () =>
                          setState(() => _filtersOpen = !_filtersOpen),
                      icon: const Icon(Icons.tune, size: 18),
                      label: Text(
                        filtered
                            ? '筛选 ${(_filter != CalendarFilter.all ? 1 : 0) + _members.length}'
                            : '筛选',
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSize(
                duration: appMotion(context, AppTokens.controlMotion),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _filtersOpen
                    ? Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: filters(wide: false),
                      )
                    : QuerySummary(
                        padding: EdgeInsets.fromLTRB(
                          AppTokens.gutter(constraints.maxWidth),
                          4,
                          AppTokens.gutter(constraints.maxWidth) - 8,
                          0,
                        ),
                        clearTooltip: '清除日历筛选',
                        onClear: reset,
                        applied: [
                          if (_filter != CalendarFilter.all)
                            (
                              label: _filter.label,
                              remove: () => setState(
                                () => _filter = CalendarFilter.all,
                              ),
                            ),
                          for (final name in _members)
                            (
                              label: name,
                              remove: () => setState(
                                () => _members = {..._members}..remove(name),
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              agenda(scrollable: false, segments: false),
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
    padding: const EdgeInsets.symmetric(horizontal: 8),
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
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
          label: Text(value.label, style: _chipText),
          selected: value == filter,
          onSelected: (_) => onFilter(value),
        ),
    ];
    final roles = [
      for (final name in EventClassifier.memberAliases.keys)
        AppChoice(
          avatar: CircleAvatar(
            backgroundColor: AppTheme.memberColors[name],
            radius: 5,
          ),
          label: Text(name, style: _chipText),
          selected: members.contains(name),
          onSelected: (_) => onMember(name),
        ),
    ];
    Widget row(List<Widget> children) => wide
        ? Wrap(spacing: 6, runSpacing: 4, children: children)
        : HorizontalChoices(children: children);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(types),
          const SizedBox(height: 4),
          if (wide) ...[
            Text('成员', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
          ],
          row(roles),
          if (filter != CalendarFilter.all || members.isNotEmpty)
            AppButton(
              onPressed: onReset,
              child: const Text('重置筛选', style: _chipText),
            ),
        ],
      ),
    );
  }
}

const _chipText = TextStyle(fontSize: 13);

class _DayOrWeek extends StatelessWidget {
  const _DayOrWeek({required this.week, required this.onWeek});
  final bool week;
  final ValueChanged<bool> onWeek;
  @override
  Widget build(BuildContext context) => AppSegments<bool>(
    values: const [false, true],
    labelOf: (value) => value ? '周议程' : '当天',
    selected: week,
    onChanged: onWeek,
  );
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
          const SizedBox(height: 2),
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
          const SizedBox(height: 2),
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
    (MediaQuery.textScalerOf(context).scale(13) * 1.35 + 14).clamp(
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
          margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
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
                  ).textTheme.bodyMedium?.copyWith(fontSize: 13, height: 1.35),
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 5,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // One dot per event in its member's colour; the selected
                    // day's pink fill would swallow a pink dot, so it rings.
                    for (final event in events.take(3))
                      Container(
                        width: 5,
                        height: 5,
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
    this.segments = true,
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

  /// Whether the day/week switch leads the agenda (the compact layout puts
  /// it in the control row instead).
  final bool segments;
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
      if (segments) ...[
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: _DayOrWeek(week: week, onWeek: onWeek),
          ),
        ),
        const SizedBox(height: 12),
      ],
      Semantics(
        header: true,
        child: Text(
          week
              ? '${CalendarAgenda.date(from)} — ${CalendarAgenda.date(until.subtract(const Duration(days: 1)))}'
              : CalendarAgenda.date(day),
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      const SizedBox(height: 8),
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
                    padding: const EdgeInsets.fromLTRB(0, 12, 0, 2),
                    child: Text(
                      CalendarAgenda.date(entry.key),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                // Quiet lines: a day with several events reads as a
                // schedule, not a stack of coloured banners.
                for (final event in entry.value)
                  CalendarAgendaRow(event: event),
              ],
              // A single day also says what comes next, from what is
              // already loaded, so the next event is never a hunt.
              if (!week)
                ...() {
                  final later =
                      events
                          .where(
                            (event) =>
                                !event.isCancelled &&
                                !CalendarTime.dayOf(
                                  event.start,
                                  allDay: event.allDay,
                                ).isBefore(until),
                          )
                          .toList()
                        ..sort((a, b) => a.start.compareTo(b.start));
                  return [
                    if (later.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 20, 0, 2),
                        child: Text(
                          '之后',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ),
                    for (final event in later.take(3))
                      CalendarAgendaRow(event: event, showDay: true),
                  ];
                }(),
            ],
          );
        },
      ),
    ];
    return ListView(
      padding: scrollable
          ? pageInsets(context, top: 16)
          : const EdgeInsets.fromLTRB(16, 8, 16, 0),
      shrinkWrap: !scrollable,
      primary: false,
      physics: scrollable ? null : const NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}
