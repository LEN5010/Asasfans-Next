import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/member_tone.dart';
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
import '../application/calendar_follow_selection.dart';
import '../../../app/providers.dart';
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
  bool _following = false;
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
    final follows = ref.watch(calendarFollowSelectionProvider).valueOrNull;
    final source = ref.watch(appEnvironmentProvider).calendarUrl;
    final events = (snapshot.valueOrNull?.events ?? const <CalendarEvent>[])
        .where(
          (event) =>
              CalendarAgenda.visible(
                event,
                filter: _filter,
                members: _members,
              ) &&
              (!_following || (follows?.contains(event, source) ?? false)),
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
    final filtered =
        _following || _filter != CalendarFilter.all || _members.isNotEmpty;
    void reset() => setState(() {
      _filter = CalendarFilter.all;
      _members = {};
      _following = false;
    });
    void toggleMember(String value) => setState(
      () => _members = _members.contains(value)
          ? ({..._members}..remove(value))
          : {..._members, value},
    );
    Widget filters() => _CalendarFilters(
      following: _following,
      onFollowing: (value) => setState(() => _following = value),
      filter: _filter,
      members: _members,
      onFilter: (value) => setState(() => _filter = value),
      onMember: toggleMember,
      onReset: reset,
    );
    Widget agenda({required bool scrollable, bool segments = true}) => _Agenda(
      key: ValueKey('calendar-agenda-$scrollable'),
      day: selected,
      today: today,
      now: ref.watch(currentTimeProvider)(),
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
                        padding: const EdgeInsets.only(left: 12, bottom: 16),
                        child: heading,
                      ),
                      AppCard(
                        padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
                        child: Column(
                          children: [
                            monthHeader(),
                            _MonthGrid(
                              month: month,
                              selected: selected,
                              today: today,
                              byDay: byDay,
                              onSelect: _select,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _MonthOverview(
                        following: _following,
                        isFollowed: (event) =>
                            follows?.contains(event, source) ?? false,
                        onFollowing: (value) =>
                            setState(() => _following = value),
                        events: (snapshot.valueOrNull?.events ?? const [])
                            .where((event) {
                              final start = CalendarTime.dayOf(
                                event.start,
                                allDay: event.allDay,
                              );
                              return !event.isCancelled &&
                                  start.year == month.year &&
                                  start.month == month.month;
                            })
                            .toList(),
                        filter: _filter,
                        members: _members,
                        onFilter: (value) => setState(() => _filter = value),
                        onMember: toggleMember,
                        onReset: reset,
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    // A reading column: an event's time, title and kind
                    // stay together however wide the window.
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
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
              const SizedBox(height: 16),
              // The month or the week, as one card the dates live in.
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppTokens.gutter(constraints.maxWidth),
                ),
                child: AppCard(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
                  child: Column(
                    children: [
                      monthHeader(collapsible: true),
                      AnimatedSize(
                        duration: appMotion(context, AppTokens.controlMotion),
                        curve: AppCurves.standard,
                        alignment: Alignment.topCenter,
                        child: _monthExpanded
                            ? _MonthGrid(
                                month: month,
                                selected: selected,
                                today: today,
                                byDay: byDay,
                                onSelect: _select,
                              )
                            : Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: CalendarWeekStrip(
                                  selected: selected,
                                  today: today,
                                  events: events,
                                  onSelect: _select,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
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
                            ? '筛选 ${(_following ? 1 : 0) + (_filter != CalendarFilter.all ? 1 : 0) + _members.length}'
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
                        child: filters(),
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
                          if (_following)
                            (
                              label: '只看关注',
                              remove: () => setState(() => _following = false),
                            ),
                          if (_filter != CalendarFilter.all)
                            (
                              label: _filter.label,
                              remove: () =>
                                  setState(() => _filter = CalendarFilter.all),
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
    // Clear of the card's rounded corners, not tucked into them.
    padding: const EdgeInsets.symmetric(horizontal: 12),
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
    required this.filter,
    required this.following,
    required this.onFollowing,
    required this.members,
    required this.onFilter,
    required this.onMember,
    required this.onReset,
  });
  final bool following;
  final ValueChanged<bool> onFollowing;
  final CalendarFilter filter;
  final Set<String> members;
  final ValueChanged<CalendarFilter> onFilter;
  final ValueChanged<String> onMember;
  final VoidCallback onReset;
  @override
  Widget build(BuildContext context) {
    final types = [
      AppChoice(
        label: const Text('只看关注', style: _chipText),
        selected: following,
        onSelected: onFollowing,
      ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HorizontalChoices(children: types),
          const SizedBox(height: 4),
          HorizontalChoices(children: roles),
          if (following || filter != CalendarFilter.all || members.isNotEmpty)
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

/// The month at a glance beside its grid: how many events it holds, of
/// which kind, and how many each member has, as a bar in her colour. The
/// kinds and the rows are the filters too: a tap narrows the dates and the
/// agenda to them, and tapping again lets go.
class _MonthOverview extends StatelessWidget {
  const _MonthOverview({
    required this.following,
    required this.isFollowed,
    required this.onFollowing,
    required this.events,
    required this.filter,
    required this.members,
    required this.onFilter,
    required this.onMember,
    required this.onReset,
  });

  final bool following;
  final bool Function(CalendarEvent) isFollowed;
  final ValueChanged<bool> onFollowing;

  /// The month's events that are going ahead, whatever the filters.
  final List<CalendarEvent> events;
  final CalendarFilter filter;
  final Set<String> members;
  final ValueChanged<CalendarFilter> onFilter;
  final ValueChanged<String> onMember;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final ofKind = events
        .where(
          (event) =>
              CalendarAgenda.visible(event, filter: filter) &&
              (!following || isFollowed(event)),
        )
        .toList();
    final shown = ofKind
        .where((event) => CalendarAgenda.visible(event, members: members))
        .length;
    final counts = {
      for (final name in EventClassifier.memberAliases.keys)
        name: ofKind
            .where((event) => EventClassifier.members(event).contains(name))
            .length,
    };
    final most = counts.values.fold(1, math.max);
    final filtered =
        following || filter != CalendarFilter.all || members.isNotEmpty;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: '本月 '),
                      TextSpan(
                        text: '$shown',
                        style: TextStyle(
                          color: colors.primary,
                          fontFeatures: AppTheme.tabular,
                        ),
                      ),
                      TextSpan(text: filtered ? ' 场符合筛选' : ' 场安排'),
                    ],
                  ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (filtered)
                AppButton(onPressed: onReset, child: const Text('重置')),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton.withIcon(
              selected: following,
              onPressed: () => onFollowing(!following),
              icon: Icon(
                following ? Icons.star_rounded : Icons.star_outline_rounded,
              ),
              label: const Text('只看关注'),
            ),
          ),
          const SizedBox(height: 8),
          AppSegments<CalendarFilter>(
            values: CalendarFilter.values,
            labelOf: (value) => value.label,
            selected: filter,
            onChanged: onFilter,
          ),
          const SizedBox(height: 10),
          for (final MapEntry(key: name, value: count) in counts.entries)
            _MemberShare(
              name: name,
              count: count,
              share: count / most,
              selected: members.contains(name),
              onTap: () => onMember(name),
            ),
        ],
      ),
    );
  }
}

/// One member's line in the month: her colour, her name, her count as a
/// bar, and whether the agenda is narrowed to her.
class _MemberShare extends StatelessWidget {
  const _MemberShare({
    required this.name,
    required this.count,
    required this.share,
    required this.selected,
    required this.onTap,
  });
  final String name;
  final int count;
  final double share;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = MemberTone.of(name, theme.brightness);
    final motion = appMotion(context, AppTokens.controlMotion);
    return Semantics(
      button: true,
      selected: selected,
      label: '$name，本月 $count 场',
      excludeSemantics: true,
      child: Material(
        color: selected ? tone.wash : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  MemberDots(members: [name], size: 9),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 64,
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: selected ? FontWeight.w700 : null,
                        color: selected ? tone.text : null,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: SizedBox(
                        height: 6,
                        child: ColoredBox(
                          color: theme.colorScheme.surfaceContainerHigh,
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: AnimatedFractionallySizedBox(
                              duration: motion,
                              curve: AppCurves.standard,
                              widthFactor: share,
                              heightFactor: 1,
                              child: ColoredBox(color: tone.color),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '$count',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontFeatures: AppTheme.tabular,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
    final height = CalendarDayCell.heightFor(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          const _Weekdays(),
          const SizedBox(height: 6),
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
                return CalendarDayCell(
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

class _Agenda extends StatelessWidget {
  const _Agenda({
    required this.day,
    required this.today,
    required this.now,
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
  final DateTime today;

  /// The present moment: today's lines say whether they are over, and the
  /// next one is lifted.
  final DateTime now;
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

  CalendarEvent? nextToday(List<CalendarEvent> events) => events
      .where(
        (event) =>
            !event.isCancelled && calendarEventTiming(event, now) != '已结束',
      )
      .firstOrNull;

  @override
  Widget build(BuildContext context) {
    final from = week ? CalendarAgenda.weekStart(day) : day;
    final until = from.add(Duration(days: week ? 7 : 1));
    final going = CalendarAgenda.group(
      events.where((event) => !event.isCancelled),
      from: from,
      until: until,
    ).values.expand((list) => list).toSet().length;
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
      Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Semantics(
                    header: true,
                    child: Text(
                      week
                          ? '${CalendarAgenda.date(from)} — ${CalendarAgenda.date(until.subtract(const Duration(days: 1)))}'
                          : CalendarAgenda.date(day),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                if (!week) ...[
                  const SizedBox(width: 10),
                  _DayTag(day: day, today: today),
                ],
              ],
            ),
          ),
          // How full the day (or week) is, once it is known.
          if (snapshot.hasValue)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 4),
              child: Text(
                '$going 场',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontFeatures: AppTheme.tabular,
                ),
              ),
            ),
        ],
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
                _AgendaCard(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_available_outlined,
                            size: 28,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${week ? '这一周' : CalendarAgenda.date(day)}${filtered ? '没有符合条件的安排' : '没有安排'}',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              for (final entry in grouped.entries.where(
                (entry) => entry.value.isNotEmpty,
              )) ...[
                if (week)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 14, 0, 6),
                    child: Text(
                      CalendarAgenda.date(entry.key),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                // Quiet lines on one card: a day with several events reads
                // as a schedule, not a stack of coloured banners. Today's
                // next event is the one lifted.
                _AgendaCard(
                  children: [
                    for (final event in entry.value)
                      CalendarAgendaRow(
                        event: event,
                        now: entry.key == today ? now : null,
                        highlight:
                            entry.key == today &&
                            event == nextToday(entry.value),
                      ),
                  ],
                ),
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
                    if (later.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 20, 0, 6),
                        child: Text(
                          '之后',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ),
                      _AgendaCard(
                        children: [
                          for (final event in later.take(3))
                            CalendarAgendaRow(event: event, showDay: true),
                        ],
                      ),
                    ],
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

/// A day's events on one card; rows keep [CalendarAgendaRow]'s own
/// corners, inset so they follow the card's.
class _AgendaCard extends StatelessWidget {
  const _AgendaCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

/// Beside a day's heading: 今天, 明天 or the day of the week.
class _DayTag extends StatelessWidget {
  const _DayTag({required this.day, required this.today});
  final DateTime day;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gap = day.difference(today).inDays;
    final label = switch (gap) {
      0 => '今天',
      1 => '明天',
      -1 => '昨天',
      _ => '周${'一二三四五六日'[day.weekday - 1]}',
    };
    final current = gap == 0;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: current
            ? AppTheme.dianaPink
            : theme.colorScheme.surfaceContainerHigh,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: current ? AppTheme.ink : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
