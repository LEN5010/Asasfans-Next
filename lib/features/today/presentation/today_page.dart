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
import '../../tools/presentation/tools_sheet.dart';
import '../../updates/application/update_providers.dart';
import '../../updates/presentation/updates_section.dart';
import '../application/today_providers.dart';
import 'on_this_day_section.dart';

class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({super.key});
  @override
  ConsumerState<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends ConsumerState<TodayPage> {
  bool _refreshing = false;
  late DateTime _lastRefresh;
  late final AppLifecycleListener _lifecycle;
  @override
  void initState() {
    super.initState();
    _lastRefresh = ref.read(currentTimeProvider)();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (mounted &&
            ref.read(currentTimeProvider)().difference(_lastRefresh) >=
                const Duration(minutes: 5)) {
          unawaited(_refresh(false));
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh(bool forceCalendar) async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    _lastRefresh = ref.read(currentTimeProvider)();
    try {
      // The update pass is separate from the content reload: a failing creator
      // must not stop the feeds from refreshing, and vice versa. Both settle
      // their own failures into their own blocks, and waiting on them together
      // keeps one from being abandoned mid-flight if the other ever throws.
      await Future.wait([
        ref.read(updateControllerProvider).run(),
        ref.read(refreshTodayProvider)(forceCalendar),
      ]);
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
      return Scaffold(
        appBar: AppBar(title: const Text('今日')),
        body: const Center(child: CircularProgressIndicator()),
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
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(builder: (_) => FanartDetailPage(item: item)),
        ),
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
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/brand/asasfans.png', width: 28, height: 28),
            const SizedBox(width: 10),
            const Text('今日'),
          ],
        ),
        actions: [
          const UpdatesBellButton(),
          IconButton(
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
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1360),
          child: RefreshIndicator(
            onRefresh: () => _refresh(true),
            child: ListView(
              key: const PageStorageKey('today-scroll'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (settings.shows(HomeSection.calendar)) ...[
                  _ScheduleSection(day: day, onCalendar: _calendar),
                  const SizedBox(height: 12),
                ],
                const UpdatesSection(),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _Shortcut(
                        '二创档案',
                        Icons.palette_outlined,
                        () => context.go('/content/fanart'),
                      ),
                      _Shortcut(
                        '历史动态',
                        Icons.history,
                        () => context.go('/content/dynamics'),
                      ),
                      _Shortcut(
                        '直播日历',
                        Icons.calendar_month_outlined,
                        _calendar,
                      ),
                      _Shortcut(
                        '社区工具',
                        Icons.widgets_outlined,
                        () => showToolsSheet(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (showFanart || showClips)
                  LayoutBuilder(
                    builder: (context, constraints) =>
                        constraints.maxWidth >= 960 && showFanart && showClips
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: fanartShelf),
                              const SizedBox(width: 24),
                              Expanded(child: clipsShelf),
                            ],
                          )
                        : Column(
                            children: [
                              if (showFanart) fanartShelf,
                              if (showFanart && showClips)
                                const SizedBox(height: 24),
                              if (showClips) clipsShelf,
                            ],
                          ),
                  ),
                if (settings.shows(HomeSection.history)) ...[
                  const SizedBox(height: 28),
                  const OnThisDaySection(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut(this.title, this.icon, this.onTap);
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(title),
    ),
  );
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
        _SectionHeader(
          title: '${CalendarAgenda.date(day)} · 今日安排',
          onAll: onCalendar,
          action: '日历',
        ),
        const SizedBox(height: 10),
        schedule.when(
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
                      padding: const EdgeInsets.only(bottom: 8),
                      child: CalendarEventTile(
                        event: event,
                        day: next ? null : day,
                        showDate: next,
                      ),
                    ),
                  if (entries.length > 2)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: onCalendar,
                        child: Text('还有 ${entries.length - 2} 项安排'),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ContentShelf<T> extends StatelessWidget {
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _SectionHeader(title: title, onAll: onAll),
      const SizedBox(height: 10),
      items.when(
        loading: () => const _SectionLoading(),
        error: (error, _) => _SectionError(error: error, onRetry: onRetry),
        data: (raw) => RuleFilterScope(
          items: raw,
          subjectOf: subjectOf,
          builder: (visible) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RuleStatusBar(visibility: visible),
              _cards(visible.items.take(6).toList()),
            ],
          ),
        ),
      ),
    ],
  );
  Widget _cards(List<T> values) => values.isEmpty
      ? const _EmptySection('暂时没有内容')
      : LayoutBuilder(
          builder: (context, constraints) {
            final width = math.min(240.0, constraints.maxWidth * .78);
            final scaler = MediaQuery.textScalerOf(context);
            final height = values
                .map((value) => extent(value, width, scaler))
                .reduce(math.max);
            return SizedBox(
              height: height,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, index) => SizedBox(
                  width: width,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      height: extent(values[index], width, scaler),
                      child: card(values[index]),
                    ),
                  ),
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
  });
  final String title;
  final VoidCallback onAll;
  final String action;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      TextButton(onPressed: onAll, child: Text(action)),
    ],
  );
}

class _EmptySection extends StatelessWidget {
  const _EmptySection(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    alignment: Alignment.centerLeft,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
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
