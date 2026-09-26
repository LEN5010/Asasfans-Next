import '../../rules/application/feed_visibility.dart';
import '../../rules/presentation/rule_filter_scope.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/time/shanghai_date_provider.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../../shared/widgets/resume_when_visible.dart';
import '../../../shared/widgets/retry_button.dart';
import '../../calendar/application/calendar_providers.dart';
import '../../calendar/domain/calendar_agenda.dart';
import '../../calendar/domain/calendar_event.dart';
import '../../../shared/widgets/page_heading.dart';
import '../../calendar/presentation/calendar_event_widgets.dart';
import '../../content/presentation/video_card.dart';
import '../../content/presentation/fanart_card.dart';
import '../../content/presentation/fanart_detail_page.dart';
import '../../preferences/application/preferences_controller.dart';
import '../../preferences/domain/app_preferences.dart';
import '../../library/application/content_snapshots.dart';
import '../../library/presentation/content_actions.dart';
import '../../updates/presentation/updates_bell_button.dart';
import '../application/today_providers.dart';
import 'on_this_day_section.dart';

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
      await ref.read(refreshTodayProvider)(forceCalendar);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _calendar() {
    final day = ref.read(shanghaiDateProvider);
    ref.read(visibleMonthProvider.notifier).state = DateTime.utc(
      day.year,
      day.month,
    );
    ref.read(selectedCalendarDayProvider.notifier).state = null;
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
    final day = ref.watch(shanghaiDateProvider);
    final heading = RootHeading(
      title: '${day.month}月${day.day}日 星期${'一二三四五六日'[day.weekday - 1]}',
      subtitle: '今天，来枝江看看',
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
    final schedule = calendar
        ? _ScheduleSection(day: day, onCalendar: _calendar)
        : null;
    final works = showFanart ? const _WorksSection() : null;
    final clips = showClips ? const _ClipsSection() : null;
    return Scaffold(
      // The shell's backdrop shows through the main pages.
      backgroundColor: Colors.transparent,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1360),
          child: RefreshIndicator(
            onRefresh: () => _refresh(true),
            edgeOffset: MediaQuery.paddingOf(context).top,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final gutter = AppTokens.gutter(width);
                final edge = EdgeInsets.symmetric(horizontal: gutter);
                // Wide windows give time its own column beside the content,
                // instead of stretching a phone's single column.
                final paired =
                    schedule != null &&
                    (works != null || clips != null) &&
                    width >= 840 * MediaQuery.textScalerOf(context).scale(1);
                final modules = <Widget>[
                  if (paired)
                    Padding(
                      padding: edge,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: (width * .3).clamp(300, 380),
                            child: schedule,
                          ),
                          const SizedBox(width: 32),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ?works,
                                if (works != null && clips != null)
                                  const SizedBox(height: AppTokens.sectionGap),
                                ?clips,
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    if (schedule != null)
                      Padding(padding: edge, child: schedule),
                    if (works != null) Padding(padding: edge, child: works),
                    if (clips != null) Padding(padding: edge, child: clips),
                  ],
                  // The archive comes after today's own content.
                  if (history) OnThisDaySection(inset: edge),
                  // Every module hidden is a choice, not a failure: say so
                  // and point at the setting that undoes it.
                  if (!calendar && !history && !showClips && !showFanart)
                    Padding(padding: edge, child: const _AllHidden()),
                ];
                return ListView(
                  key: const PageStorageKey('today-scroll'),
                  padding: EdgeInsets.fromLTRB(
                    0,
                    MediaQuery.paddingOf(context).top + 16,
                    0,
                    MediaQuery.paddingOf(context).bottom + 24,
                  ),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Padding(padding: edge, child: heading),
                    for (final module in modules)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: AppTokens.sectionGap - 8,
                        ),
                        child: module,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Today's schedule, or the next thing on it: at most two lines of today,
/// else the first live event within a week.
class _ScheduleSection extends ConsumerWidget {
  const _ScheduleSection({required this.day, required this.onCalendar});
  final DateTime day;
  final VoidCallback onCalendar;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedule = ref.watch(todayScheduleProvider);
    var next = false;
    var entries = const <CalendarEvent>[];
    if (schedule case AsyncData(:final value)) {
      entries = CalendarAgenda.onDay(value.events, day);
      if (entries.isEmpty) {
        for (var offset = 1; offset <= 7; offset++) {
          entries = CalendarAgenda.onDay(
            value.events.where((event) => !event.isCancelled),
            day.add(Duration(days: offset)),
          );
          if (entries.isNotEmpty) {
            entries = entries.take(1).toList();
            next = true;
            break;
          }
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(
          title: next ? '接下来' : '今日安排',
          action: '日历',
          onAction: onCalendar,
        ),
        AppFadeSwitcher(
          phase: asyncPhase(schedule),
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
                  const _EmptySection('接下来一周没有安排')
                else ...[
                  for (final event in entries.take(2))
                    CalendarAgendaRow(event: event, showDay: next, today: day),
                  if (entries.length > 2)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AppButton(
                        onPressed: onCalendar,
                        child: Text('还有 ${entries.length - 2} 项安排'),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The newest works as a row of tiles, as many as the width holds.
class _WorksSection extends ConsumerWidget {
  const _WorksSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(todayFanartProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(
          title: '最新二创',
          action: '查看二创',
          onAction: () => context.go('/content/fanart'),
        ),
        const SizedBox(height: 4),
        AppFadeSwitcher(
          phase: asyncPhase(items),
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
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final scaler = MediaQuery.textScalerOf(context);
                        final width = constraints.maxWidth;
                        const gap = AppTokens.itemGap;
                        final minimum =
                            (width >= 760 ? 200.0 : 136.0) *
                            scaler.scale(1).clamp(1.0, 1.6);
                        final columns = ((width + gap) / (minimum + gap))
                            .floor()
                            .clamp(1, 5);
                        final cell = (width - gap * (columns - 1)) / columns;
                        final shown = visible.items.take(columns).toList();
                        return SizedBox(
                          height: FanartCard.extentFor(
                            shown.first,
                            cell,
                            scaler,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final (index, item) in shown.indexed) ...[
                                if (index > 0) const SizedBox(width: gap),
                                SizedBox(
                                  width: cell,
                                  child: FanartCard(
                                    item: item,
                                    onLongPress: () => showContentActions(
                                      context,
                                      ContentSnapshots.fanart(item),
                                    ),
                                    onTap: () => openFanart(context, ref, item),
                                  ),
                                ),
                              ],
                            ],
                          ),
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
          action: '全部视频',
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
    padding: const EdgeInsets.symmetric(vertical: 10),
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
