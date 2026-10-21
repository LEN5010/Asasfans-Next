import '../../rules/application/feed_visibility.dart';
import '../../rules/presentation/rule_filter_scope.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/time/local_date_provider.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../../shared/widgets/resume_when_visible.dart';
import '../../../shared/widgets/sliver_content_masonry.dart';
import '../../../shared/widgets/retry_button.dart';
import '../../calendar/application/calendar_providers.dart';
import '../../calendar/domain/calendar_agenda.dart';
import '../../../shared/widgets/page_heading.dart';
import '../../calendar/presentation/calendar_event_widgets.dart';
import '../../content/presentation/video_card.dart';
import '../../content/domain/fanart_repository.dart';
import '../../content/presentation/fanart_card.dart';
import '../../content/presentation/fanart_detail_page.dart';
import '../../content/presentation/random_fanart_page.dart';
import '../../preferences/application/preferences_controller.dart';
import '../../preferences/domain/app_preferences.dart';
import '../../library/application/content_snapshots.dart';
import '../../library/presentation/content_actions.dart';
import '../../updates/presentation/updates_bell_button.dart';
import '../application/today_providers.dart';
import 'on_this_day_section.dart';
import '../../handoff/presentation/continue_browsing.dart';
import '../../operations/application/operations_controller.dart';
import '../../operations/presentation/operation_widgets.dart';

class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({super.key});
  @override
  ConsumerState<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends ConsumerState<TodayPage> with ResumeWhenVisible {
  bool _refreshing = false;
  late DateTime _lastRefresh;
  @override
  void initState() {
    super.initState();
    _lastRefresh = ref.read(currentTimeProvider)();
  }

  @override
  void onVisibleResume() {
    if (ref.read(currentTimeProvider)().difference(_lastRefresh) >=
        const Duration(minutes: 5)) {
      unawaited(_refresh(false));
    }
  }

  Future<void> _refresh(bool forceCalendar) async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    _lastRefresh = ref.read(currentTimeProvider)();
    try {
      await Future.wait([
        ref.read(refreshTodayProvider)(forceCalendar),
        ref.read(operationsProvider.notifier).refresh(),
      ]);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  /// Opens the calendar on [picked], or on today (with no selection of its
  /// own, so it keeps following the date) when nothing else was picked.
  void _calendar([DateTime? picked]) {
    final DateTime day = picked ?? ref.read(localDateProvider);
    ref.read(visibleMonthProvider.notifier).state = DateTime.utc(
      day.year,
      day.month,
    );
    ref.read(selectedCalendarDayProvider.notifier).state = picked;
    context.go('/calendar');
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(preferencesControllerProvider);
    if (preferences.loading && !preferences.ready) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final settings = preferences.values;
    final showFanart = settings.shows(HomeSection.fanart);
    final showClips = settings.shows(HomeSection.clips);
    final calendar = settings.shows(HomeSection.calendar);
    final history = settings.shows(HomeSection.history);
    final day = ref.watch(localDateProvider);
    final heading = RootHeading(
      title: '${day.month}月${day.day}日 星期${'一二三四五六日'[day.weekday - 1]}',
      subtitle: _TodaySummary(day: day, calendar: calendar),
      actions: [
        const UpdatesBellButton(),
        AppButton.icon(
          tooltip: '刷新今日',
          onPressed: _refreshing ? null : () => _refresh(true),
          icon: _refreshing
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
        ),
      ],
    );
    return Scaffold(
      // The shell's backdrop shows through the main pages.
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () => _refresh(true),
        edgeOffset: MediaQuery.paddingOf(context).top,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final padding = MediaQuery.paddingOf(context);
            // The page starts where every page starts, and stops growing
            // at a readable width instead of centring itself.
            final width = math.min(constraints.maxWidth, AppTokens.pageWidth);
            final gutter = AppTokens.gutter(constraints.maxWidth);
            final edge = EdgeInsets.fromLTRB(
              gutter,
              0,
              math.max(gutter, constraints.maxWidth - width + gutter),
              0,
            );
            const gap = EdgeInsets.only(top: AppTokens.sectionGap - 8);
            Widget box(Widget child, {bool spaced = true}) =>
                SliverToBoxAdapter(
                  child: Padding(
                    padding: edge + (spaced ? gap : EdgeInsets.zero),
                    child: child,
                  ),
                );
            return CustomScrollView(
              key: const PageStorageKey('today-scroll'),
              physics: const _SettleAtEndsPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(child: SizedBox(height: padding.top + 16)),
                box(AppEntrance(child: heading), spaced: false),
                box(const CampaignCards(), spaced: false),
                box(const AnnouncementCards(), spaced: false),
                // What today holds, as a compact card at the top: a few
                // lines, never a column beside the works for the whole page.
                // Then the one optional task slot, back to where picking
                // stopped; it spaces itself, so an empty slot adds no gap.
                box(
                  AppEntrance(
                    order: 1,
                    child: _TopSummary(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (calendar)
                            _ScheduleSection(day: day, onCalendar: _calendar),
                          const ContinueBrowsingRow(),
                        ],
                      ),
                    ),
                  ),
                  spaced: calendar,
                ),
                if (history)
                  SliverPadding(
                    padding: gap,
                    sliver: SliverToBoxAdapter(
                      child: OnThisDaySection(inset: edge),
                    ),
                  ),
                if (showClips) box(const _ClipsSection()),
                if (showFanart) box(const _WorksSection()),
                // Every module hidden is a choice, not a failure: say so
                // and point at the setting that undoes it.
                if (!calendar && !history && !showClips && !showFanart)
                  box(const _AllHidden()),
                SliverToBoxAdapter(
                  child: SizedBox(height: padding.bottom + 24),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Today's two ends. A fling that would run on past either one eases
/// into it and rests there, rather than hitting it at speed or bouncing
/// off. Pulling on past an end is the platform's own: a rubber band on
/// Apple's systems that springs back when let go, and at the top the pull
/// that refreshes. Letting go mid-stretch springs back from where it is,
/// without flying further out first.
class _SettleAtEndsPhysics extends ScrollPhysics {
  const _SettleAtEndsPhysics({super.parent});

  @override
  _SettleAtEndsPhysics applyTo(ScrollPhysics? ancestor) =>
      _SettleAtEndsPhysics(parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final outward =
        (position.pixels > position.maxScrollExtent && velocity > 0) ||
        (position.pixels < position.minScrollExtent && velocity < 0);
    if (outward) return super.createBallisticSimulation(position, 0);
    final natural = super.createBallisticSimulation(position, velocity);
    if (natural == null || position.outOfRange || velocity == 0) {
      return natural;
    }
    final edge = velocity > 0
        ? position.maxScrollExtent
        : position.minScrollExtent;
    final tolerance = toleranceFor(position);
    final rest = natural.x(60);
    final reaches = velocity > 0
        ? rest >= edge - tolerance.distance
        : rest <= edge + tolerance.distance;
    if (!reaches || (edge - position.pixels).abs() <= tolerance.distance) {
      return natural;
    }
    // Slowing all the way from here, arriving at the edge as it stops.
    return FrictionSimulation.through(
      position.pixels,
      edge,
      velocity,
      velocity.sign * tolerance.velocity,
    );
  }
}

/// The top of Today holds a few lines, at a width a line can be read at.
class _TopSummary extends StatelessWidget {
  const _TopSummary({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppTokens.readingWidth),
      child: child,
    ),
  );
}

/// The line under Today's date: a greeting for the hour, and how much the
/// day holds once the schedule is known.
class _TodaySummary extends ConsumerWidget {
  const _TodaySummary({required this.day, required this.calendar});
  final DateTime day;
  final bool calendar;

  static String greeting(DateTime now) {
    final hour = now.toLocal().hour;
    return switch (hour) {
      < 5 => '夜深了',
      < 11 => '早上好',
      < 13 => '中午好',
      < 18 => '下午好',
      < 23 => '晚上好',
      _ => '夜深了',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hello = greeting(ref.watch(currentTimeProvider)());
    final events = calendar
        ? ref.watch(todayScheduleProvider).valueOrNull?.events
        : null;
    if (events == null) return Text('$hello，来枝江看看');
    final count = CalendarAgenda.onDay(
      events.where((event) => !event.isCancelled),
      day,
    ).length;
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        text: '$hello，',
        children: [
          if (count == 0)
            const TextSpan(text: '今天没有安排')
          else ...[
            const TextSpan(text: '今天有 '),
            TextSpan(
              text: '$count',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
                fontFeatures: AppTheme.tabular,
              ),
            ),
            const TextSpan(text: ' 项安排'),
          ],
        ],
      ),
    );
  }
}

/// Today's schedule as one card: this week as a strip of days, a dot per
/// event in its member's colour, and the chosen day's events beneath. The
/// chosen day is today until another is tapped; today's next event is
/// lifted with how soon it starts, and an empty today falls forward to the
/// first live event within a week. At most two lines, then a count.
class _ScheduleSection extends ConsumerStatefulWidget {
  const _ScheduleSection({required this.day, required this.onCalendar});
  final DateTime day;
  final void Function([DateTime? picked]) onCalendar;

  @override
  ConsumerState<_ScheduleSection> createState() => _ScheduleSectionState();
}

class _ScheduleSectionState extends ConsumerState<_ScheduleSection> {
  /// Another day of the week, once tapped; null is today.
  DateTime? _picked;
  late DateTime _now = ref.read(currentTimeProvider)();
  Timer? _tick;

  static const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  @override
  void initState() {
    super.initState();
    // How soon the next event starts is told to the minute; a hidden tab
    // does not redraw for it.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || !TickerMode.valuesOf(context).enabled) return;
      setState(() => _now = ref.read(currentTimeProvider)());
    });
  }

  @override
  void didUpdateWidget(_ScheduleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.day != widget.day) _picked = null;
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final schedule = ref.watch(todayScheduleProvider);
    final week = ref.watch(todayWeekProvider).valueOrNull;
    final now = ref.watch(currentTimeProvider)();
    if (now.isAfter(_now)) _now = now;
    // Today's month and the week together, each event once.
    final seen = <String>{};
    final pool = [
      for (final event in [...?schedule.valueOrNull?.events, ...?week])
        if (seen.add(event.identity)) event,
    ];
    final nextFollowed = ref
        .watch(followedLivesProvider)
        .valueOrNull
        ?.where((event) => event.start.isAfter(_now))
        .firstOrNull;
    final selected = _picked ?? day;
    final isToday = selected == day;
    var next = false;
    var entries = CalendarAgenda.onDay(pool, selected);
    if (isToday && entries.isEmpty) {
      for (var offset = 1; offset <= 7; offset++) {
        entries = CalendarAgenda.onDay(
          pool.where((event) => !event.isCancelled),
          day.add(Duration(days: offset)),
        );
        if (entries.isNotEmpty) {
          entries = entries.take(1).toList();
          next = true;
          break;
        }
      }
    }
    // Today's lines start at the next event; earlier ones are over.
    final lift = isToday
        ? entries.indexWhere(
            (event) =>
                !event.isCancelled && calendarEventTiming(event, _now) != '已结束',
          )
        : -1;
    final first = lift >= 0
        ? lift
        : isToday
        ? (entries.length - 2).clamp(0, entries.length)
        : 0;
    final shown = entries.skip(first).take(2).toList();
    final hidden = entries.length - shown.length;
    final title = next
        ? '接下来'
        : isToday
        ? '今日安排'
        : '${_weekdays[selected.weekday - 1]}安排';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (nextFollowed != null) ...[
          const SectionHeading(title: '关注的下一场'),
          const SizedBox(height: 4),
          AppCard(
            padding: const EdgeInsets.all(6),
            child: CalendarAgendaRow(
              event: nextFollowed,
              showDay: true,
              today: day,
              now: _now,
              highlight: true,
            ),
          ),
          const SizedBox(height: 16),
        ],
        SectionHeading(
          title: title,
          action: '日历',
          onAction: () => widget.onCalendar(_picked),
        ),
        const SizedBox(height: 4),
        AppCard(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CalendarWeekStrip(
                selected: selected,
                today: day,
                events: pool,
                onSelect: (value) =>
                    setState(() => _picked = value == day ? null : value),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 10, 8, 6),
                child: Divider(height: 1),
              ),
              AppFadeSwitcher(
                phase: (asyncPhase(schedule), selected),
                child: schedule.when(
                  loading: () => const _SectionLoading(),
                  error: (error, _) => _SectionError(
                    error: error,
                    onRetry: () => ref.invalidate(
                      monthEventsProvider(DateTime.utc(day.year, day.month)),
                    ),
                  ),
                  data: (snapshot) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (snapshot.isStale)
                        CalendarStaleBanner(fetchedAt: snapshot.fetchedAt),
                      if (snapshot.offlineCacheUnavailable)
                        const CalendarCacheFailureBanner(),
                      if (snapshot.followSyncUnavailable)
                        const CalendarFollowSyncBanner(),
                      if (entries.isEmpty)
                        _EmptySection(isToday ? '接下来一周没有安排' : '这一天没有安排')
                      else ...[
                        for (final event in shown)
                          CalendarAgendaRow(
                            event: event,
                            showDay: next,
                            today: day,
                            now: _now,
                            highlight:
                                isToday && event == entries[first] && lift >= 0,
                          ),
                        if (hidden > 0)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: AppButton(
                              onPressed: () => widget.onCalendar(_picked),
                              child: Text('还有 $hidden 项安排'),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A random handful of works, two rows of one tile shape, so the rows line
/// up whatever each work is. 换一批 draws again; the current works stay
/// until the next ones arrive.
class _WorksSection extends ConsumerWidget {
  const _WorksSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(todayFanartProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(
          title: '随机二创',
          trailing: [
            AppButton.icon(
              tooltip: '换一批',
              onPressed: items.isLoading
                  ? null
                  : () => ref.invalidate(todayFanartProvider),
              icon: const Icon(Icons.refresh, size: 20),
            ),
            const SizedBox(width: 4),
            // The same draw, without end: the lead way in.
            const RandomFanartButton(label: '一直刷'),
          ],
        ),
        const SizedBox(height: 4),
        AppFadeSwitcher(
          phase: (asyncPhase(items), items.valueOrNull),
          child: items.when(
            loading: () => const _SectionLoading(),
            error: (error, _) => _SectionError(
              error: error,
              onRetry: () => ref.invalidate(todayFanartProvider),
            ),
            data: (raw) => RuleFilterScope(
              items: raw,
              subjectOf: RuleSubjects.fanart,
              builder: (visible) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RuleStatusBar(visibility: visible),
                  if (visible.items.isEmpty)
                    const _EmptySection('暂时没有内容')
                  else
                    _WorksGrid(items: visible.items),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Two rows of equal tiles, as many columns as the width holds.
class _WorksGrid extends ConsumerWidget {
  const _WorksGrid({required this.items});
  final List<FanartItem> items;
  @override
  Widget build(BuildContext context, WidgetRef ref) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final gap = SliverContentMasonry.spacingFor(width);
      final columns = SliverContentMasonry.columnsFor(
        width,
        MediaQuery.textScalerOf(context),
        maxColumns: todayFanartCount ~/ 2,
      );
      final tile = (width - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap + 4,
        children: [
          for (final item in items.take(columns * 2))
            SizedBox(
              width: tile,
              child: FanartCard(
                key: ValueKey(item.identity),
                item: item,
                uniform: true,
                onLongPress: () =>
                    showContentActions(context, ContentSnapshots.fanart(item)),
                onTap: () => openFanart(context, ref, item),
              ),
            ),
        ],
      );
    },
  );
}

/// A few new clips as list lines: they accompany the works, not compete.
class _ClipsSection extends ConsumerWidget {
  const _ClipsSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(todayClipsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(
          title: '最新切片',
          action: '查看切片',
          onAction: () => context.go('/content/clips'),
        ),
        AppFadeSwitcher(
          phase: asyncPhase(items),
          child: items.when(
            loading: () => const _SectionLoading(),
            error: (error, _) => _SectionError(
              error: error,
              onRetry: () => ref.invalidate(todayClipsProvider),
            ),
            data: (raw) => RuleFilterScope(
              items: raw,
              subjectOf: RuleSubjects.video,
              builder: (visible) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RuleStatusBar(visibility: visible),
                  if (visible.items.isEmpty)
                    const _EmptySection('暂时没有内容')
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // Two columns of lines once each can keep ~340 px.
                        final columns = constraints.maxWidth >= 700 ? 2 : 1;
                        final shown = visible.items
                            .take(columns == 2 ? 4 : 3)
                            .toList();
                        return Wrap(
                          spacing: 24,
                          children: [
                            for (final video in shown)
                              SizedBox(
                                width: columns == 2
                                    ? (constraints.maxWidth - 24) / 2
                                    : constraints.maxWidth,
                                child: VideoRow(video: video),
                              ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class _AllHidden extends StatelessWidget {
  const _AllHidden();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _EmptySection('首页模块都已隐藏'),
      AppButton.withIcon(
        icon: const Icon(Icons.tune),
        label: const Text('在“我的 · 设置”中显示模块'),
        onPressed: () => context.go('/mine/settings'),
      ),
    ],
  );
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading();
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 100,
    child: Center(
      child: SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      children: [
        Text(error is ApiFailure ? (error as ApiFailure).message : '内容加载失败'),
        const SizedBox(height: 8),
        RetryButton(
          failure: error is ApiFailure ? error as ApiFailure : null,
          onRetry: onRetry,
        ),
      ],
    ),
  );
}
