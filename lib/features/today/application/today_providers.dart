import '../../../core/network/api_failure.dart';
import '../../rules/application/feed_visibility.dart';
import '../../rules/application/rules_providers.dart';
import '../../../core/domain/content_identity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/shanghai_date_provider.dart';
import '../../calendar/application/calendar_providers.dart';
import '../../calendar/application/calendar_follow_selection.dart';
import '../../calendar/domain/event_classifier.dart';
import '../../../app/providers.dart';
import '../../calendar/domain/calendar_agenda.dart';
import '../../calendar/domain/calendar_event.dart';
import '../../content/application/community_video_pager.dart';
import '../../content/application/content_providers.dart';
import '../../content/domain/community_video_repository.dart';
import '../../content/domain/fanart_repository.dart';
import '../../preferences/application/preferences_controller.dart';
import '../../preferences/domain/app_preferences.dart';

final todayScheduleProvider = FutureProvider.autoDispose<CalendarSnapshot>((
  ref,
) {
  final day = ref.watch(shanghaiDateProvider);
  return ref.watch(
    monthEventsProvider(DateTime.utc(day.year, day.month)).future,
  );
});

/// Today's week, Monday to Sunday, for the strip of days above the
/// schedule: the month holding today, and the neighbouring one too when the
/// week runs across a month's edge. Each event appears once, whichever
/// month carried it.
final todayWeekProvider = FutureProvider.autoDispose<List<CalendarEvent>>((
  ref,
) async {
  final day = ref.watch(shanghaiDateProvider);
  final monday = CalendarAgenda.weekStart(day);
  final sunday = monday.add(const Duration(days: 6));
  final months = {
    DateTime.utc(monday.year, monday.month),
    DateTime.utc(sunday.year, sunday.month),
  };
  final snapshots = await Future.wait([
    for (final month in months) ref.watch(monthEventsProvider(month).future),
  ]);
  final seen = <String>{};
  return List.unmodifiable([
    for (final snapshot in snapshots)
      for (final event in snapshot.events)
        if (seen.add(event.identity)) event,
  ]);
});

final todayFollowedLivesProvider =
    FutureProvider.autoDispose<List<CalendarEvent>>((ref) async {
      final selection = await ref.watch(calendarFollowSelectionProvider.future);
      await ref.watch(todayScheduleProvider.future);
      final source = ref.watch(appEnvironmentProvider).calendarUrl;
      final now = ref.read(currentTimeProvider)();
      final events = await ref
          .watch(calendarEventStoreProvider)
          .readEvents(
            source,
            from: now,
            until: now.add(const Duration(days: 30)),
          );
      return events
          .where(
            (event) =>
                !event.isCancelled &&
                !event.allDay &&
                EventClassifier.classify(event) == EventKind.live &&
                selection.contains(event, source),
          )
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));
    });

/// A random handful of works: a fresh draw on each load, pull to refresh
/// and 换一批, not tied to the day. One request brings up to ten from each
/// source; a second is made only when the rules leave too few for two rows.
final todayFanartProvider = FutureProvider.autoDispose<List<FanartItem>>((
  ref,
) async {
  final cancellation = RequestCancellation();
  ref.onDispose(cancellation.cancel);
  final repository = ref.watch(fanartRepositoryProvider);
  final rules = ref.read(rulesControllerProvider.notifier);
  final items = <FanartItem>[];
  final seen = <ContentIdentity>{};
  for (var draw = 0; draw < 2; draw++) {
    final batch = await repository.sample(
      query: const FanartQuery(limit: todayFanartCount),
      cancellation: cancellation,
    );
    if (cancellation.isCancelled) {
      throw const ApiFailure(ApiFailureKind.cancelled);
    }
    items.addAll(batch.where((item) => seen.add(item.identity)));
    if (batch.isEmpty) break;
    final policy = await rules.ready();
    if (cancellation.isCancelled) {
      throw const ApiFailure(ApiFailureKind.cancelled);
    }
    if (projectFeed(items, RuleSubjects.fanart, policy).items.length >=
        todayFanartCount) {
      break;
    }
  }
  return List.unmodifiable(items);
});

/// The most works Today shows: two rows of at most five.
const todayFanartCount = 10;

final todayClipsProvider = FutureProvider.autoDispose<List<CommunityVideo>>((
  ref,
) async {
  ref.watch(shanghaiDateProvider);
  final cancellation = RequestCancellation();
  ref.onDispose(cancellation.cancel);
  final pager = CommunityVideoPager(
    ref.watch(communityVideoRepositoryProvider),
    query: const CommunityVideoQuery(),
    anyTags: CommunityChannel.clips.tags,
    now: ref.read(currentTimeProvider)(),
    pageSize: 6,
  );
  final rules = ref.read(rulesControllerProvider.notifier);
  final items = <CommunityVideo>[];
  for (var scan = 0; scan < 3; scan++) {
    final page = await pager.next(cancellation: cancellation);
    if (cancellation.isCancelled) {
      throw const ApiFailure(ApiFailureKind.cancelled);
    }
    items.addAll(page.videos);
    if (!page.hasMore) break;
    final policy = await rules.ready();
    if (cancellation.isCancelled) {
      throw const ApiFailure(ApiFailureKind.cancelled);
    }
    if (projectFeed(items, RuleSubjects.video, policy).items.length >= 6) break;
  }
  return List.unmodifiable(items);
});

/// Each module owns its error state. A failed source must not prevent refresh
/// of the other modules or surface several page-level snackbars at once.
final refreshTodayProvider = Provider<Future<void> Function(bool)>((ref) {
  return (forceCalendar) async {
    final preferences = ref.read(preferencesControllerProvider);
    if (preferences.loading && !preferences.ready) return;
    final settings = preferences.values;
    final day = ref.read(shanghaiDateProvider);
    final month = DateTime.utc(day.year, day.month);
    Future<void> calendar() async {
      if (forceCalendar) {
        await ref.read(refreshCalendarProvider)(month);
      } else {
        ref.invalidate(monthEventsProvider(month));
        await ref.read(monthEventsProvider(month).future);
      }
    }

    await Future.wait([
      if (settings.shows(HomeSection.fanart))
        _settle(ref.refresh(todayFanartProvider.future)),
      if (settings.shows(HomeSection.clips))
        _settle(ref.refresh(todayClipsProvider.future)),
      if (settings.shows(HomeSection.history))
        _settle(ref.refresh(onThisDayProvider.future)),
      if (settings.shows(HomeSection.calendar)) _settle(calendar()),
    ]);
  };
});

Future<void> _settle<T>(Future<T> request) async {
  try {
    await request;
  } catch (_) {
    /* The owning AsyncValue keeps the error. */
  }
}
