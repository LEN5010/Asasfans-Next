import '../../rules/application/feed_visibility.dart';
import '../../rules/domain/content_rules.dart';
import '../../rules/presentation/rule_filter_scope.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/time/shanghai_date_provider.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/app_page_bar.dart';
import '../../../shared/widgets/media_grid_delegate.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../../shared/widgets/resume_when_visible.dart';
import '../../../shared/widgets/retry_button.dart';
import '../../calendar/application/calendar_providers.dart';
import '../../calendar/domain/calendar_agenda.dart';
import '../../calendar/presentation/calendar_event_widgets.dart';
import '../../content/presentation/video_card.dart';
import '../../content/presentation/fanart_card.dart';
import '../../content/presentation/fanart_detail_page.dart';
import '../../content/domain/fanart_repository.dart';
import '../../content/domain/community_video_repository.dart';
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
        appBar: AppPageBar(title: Text('今日')),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final settings = preferences.values;
    final showFanart = settings.shows(HomeSection.fanart);
    final showClips = settings.shows(HomeSection.clips);
    final fanart = showFanart
        ? ref.watch(todayFanartProvider)
        : const AsyncData<List<FanartItem>>([]);
    final clips = showClips
        ? ref.watch(todayClipsProvider)
        : const AsyncData<List<CommunityVideo>>([]);
    final day = ref.watch(shanghaiDateProvider);
    final fanartShelf = _ContentShelf(
      title: '最新二创',
      items: fanart,
      onAll: () => context.go('/content/fanart'),
      onRetry: () => ref.invalidate(todayFanartProvider),
      extent: FanartCard.extentFor,
      subjectOf: RuleSubjects.fanart,
      card: (item) => FanartCard(
        item: item,
        onLongPress: () =>
            showContentActions(context, ContentSnapshots.fanart(item)),
        onTap: () => openFanart(context, ref, item),
      ),
    );
    final clipsShelf = _ContentShelf(
      title: '最新切片',
      items: clips,
      onAll: () => context.go('/content/clips'),
      onRetry: () => ref.invalidate(todayClipsProvider),
      extent: VideoCard.extentFor,
      subjectOf: RuleSubjects.video,
      card: (video) => VideoCard(video: video),
    );
    return Scaffold(
      extendBodyBehindAppBar: true,
      // The shell's backdrop shows through the main pages.
      backgroundColor: Colors.transparent,
      appBar: AppPageBar(
        title: Text('今日 · ${CalendarAgenda.date(day)}'),
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
      ),
      body: Builder(
        // Inside the body, so MediaQuery carries the page bar height.
        builder: (context) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1360),
            child: RefreshIndicator(
              onRefresh: () => _refresh(true),
              edgeOffset: MediaQuery.paddingOf(context).top,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final calendar = settings.shows(HomeSection.calendar);
                  final history = settings.shows(HomeSection.history);
                  final paired =
                      calendar &&
                      history &&
                      // Measured after the desktop rail, so a mid-size window
                      // pairs instead of stretching the schedule full width.
                      constraints.maxWidth >=
                          680 * MediaQuery.textScalerOf(context).scale(1);
                  // Horizontal shelves run to the edges and carry the page
                  // inset themselves, so cards are not cut at the margin.
                  const edge = EdgeInsets.symmetric(horizontal: 16);
                  return ListView(
                    key: const PageStorageKey('today-scroll'),
                    padding: pageInsets(context, horizontal: 0, top: 4),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      for (final (index, module) in <Widget>[
                        if (paired)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: SizedBox(
                                  width: (constraints.maxWidth * .32).clamp(
                                    280,
                                    360,
                                  ),
                                  child: _ScheduleSection(
                                    day: day,
                                    onCalendar: _calendar,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 24),
                              const Expanded(
                                child: OnThisDaySection(
                                  inset: EdgeInsets.only(right: 16),
                                ),
                              ),
                            ],
                          )
                        else ...[
                          if (calendar)
                            Padding(
                              padding: edge,
                              child: _ScheduleSection(
                                day: day,
                                onCalendar: _calendar,
                              ),
                            ),
                          if (history) const OnThisDaySection(inset: edge),
                        ],
                        if (showClips) clipsShelf,
                        if (showFanart) fanartShelf,
                        // Every module hidden is a choice, not a failure:
                        // say so and point at the setting that undoes it.
                        if (!calendar && !history && !showClips && !showFanart)
                          const Padding(padding: edge, child: _AllHidden()),
                      ].indexed)
                        Padding(
                          padding: EdgeInsets.only(top: index == 0 ? 0 : 20),
                          child: module,
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScheduleSection extends ConsumerWidget {
  const _ScheduleSection({required this.day, required this.onCalendar});
  final DateTime day;
  final VoidCallback onCalendar;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedule = ref.watch(todayScheduleProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(title: '今日安排', onAll: onCalendar, action: '日历'),
        const SizedBox(height: 6),
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
            data: (snapshot) {
              var entries = CalendarAgenda.onDay(snapshot.events, day);
              var next = false;
              if (entries.isEmpty) {
                for (var offset = 1; offset <= 7; offset++) {
                  entries = CalendarAgenda.onDay(
                    snapshot.events.where((event) => !event.isCancelled),
                    day.add(Duration(days: offset)),
                  );
                  if (entries.isNotEmpty) {
                    entries = entries.take(1).toList();
                    next = true;
                    break;
                  }
                }
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (snapshot.isStale)
                    CalendarStaleBanner(fetchedAt: snapshot.fetchedAt),
                  if (snapshot.offlineCacheUnavailable)
                    const CalendarCacheFailureBanner(),
                  if (snapshot.followSyncUnavailable)
                    const CalendarFollowSyncBanner(),
                  if (entries.isEmpty)
                    const _EmptySection('今天没有安排')
                  else ...[
                    if (next)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '接下来',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                    for (final event in entries.take(2))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: CalendarEventTile(
                          event: event,
                          day: next ? null : day,
                          showDate: next,
                          compact: true,
                        ),
                      ),
                    if (entries.length > 2)
                      Align(
                        alignment: Alignment.centerRight,
                        child: AppButton(
                          onPressed: onCalendar,
                          child: Text('还有 ${entries.length - 2} 项安排'),
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ContentShelf<T> extends StatefulWidget {
  const _ContentShelf({
    required this.title,
    required this.items,
    required this.onAll,
    required this.onRetry,
    required this.extent,
    required this.subjectOf,
    required this.card,
  });
  final String title;
  final AsyncValue<List<T>> items;
  final VoidCallback onAll;
  final VoidCallback onRetry;
  final double Function(T, double, TextScaler) extent;
  final RuleSubject Function(T) subjectOf;
  final Widget Function(T) card;
  @override
  State<_ContentShelf<T>> createState() => _ContentShelfState<T>();
}

class _ContentShelfState<T> extends State<_ContentShelf<T>> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _move(int direction) {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      (_scroll.offset + direction * _scroll.position.viewportDimension * .76)
          .clamp(0, _scroll.position.maxScrollExtent),
      duration: appMotion(context, AppTokens.controlMotion),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // The shelf runs to the page edges; only its heading keeps the inset.
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _SectionHeader(
          title: widget.title,
          onAll: widget.onAll,
          onPrevious: () => _move(-1),
          onNext: () => _move(1),
        ),
      ),
      const SizedBox(height: 6),
      AppFadeSwitcher(
        phase: asyncPhase(widget.items),
        child: widget.items.when(
          loading: () => const _SectionLoading(),
          error: (error, _) =>
              _SectionError(error: error, onRetry: widget.onRetry),
          data: (raw) => RuleFilterScope(
            items: raw,
            subjectOf: widget.subjectOf,
            builder: (visible) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: RuleStatusBar(visibility: visible),
                ),
                _cards(visible.items.take(6).toList()),
              ],
            ),
          ),
        ),
      ),
    ],
  );
  Widget _cards(List<T> values) => values.isEmpty
      ? const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: _EmptySection('暂时没有内容'),
        )
      : LayoutBuilder(
          builder: (context, constraints) {
            final scaler = MediaQuery.textScalerOf(context);
            // Match the existing video grid instead of enlarging shelf cards.
            final columns = MediaGridDelegate.columnsFor(
              constraints.maxWidth,
              textScale: scaler.scale(1),
            );
            final width = MediaGridDelegate.cellWidth(
              constraints.maxWidth,
              columns,
            );
            final gap = MediaGridDelegate.spacingFor(constraints.maxWidth);
            final height = values
                .map((value) => widget.extent(value, width, scaler))
                .reduce(math.max);
            return SizedBox(
              height: height,
              child: ListView.separated(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: values.length,
                separatorBuilder: (_, _) => SizedBox(width: gap),
                itemBuilder: (_, index) => SizedBox(
                  width: width,
                  height: height,
                  child: widget.card(values[index]),
                ),
              ),
            );
          },
        );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.onAll,
    this.action = '更多',
    this.onPrevious,
    this.onNext,
  });
  final String title;
  final VoidCallback onAll;
  final String action;
  final VoidCallback? onPrevious, onNext;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      if (onPrevious != null && MediaQuery.sizeOf(context).width >= 760)
        AppButton.icon(
          tooltip: '上一组$title',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
      if (onNext != null && MediaQuery.sizeOf(context).width >= 760)
        AppButton.icon(
          tooltip: '下一组$title',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      AppButton(onPressed: onAll, child: Text(action)),
    ],
  );
}

class _EmptySection extends StatelessWidget {
  const _EmptySection(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    alignment: Alignment.centerLeft,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppTokens.cardRadius),
    ),
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
      const SizedBox(height: 8),
      AppButton.withIcon(
        icon: const Icon(Icons.tune),
        label: const Text('在“我的 · 偏好”中显示模块'),
        onPressed: () => context.go('/mine'),
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
