import '../../../core/network/api_failure.dart';
import '../../rules/application/feed_visibility.dart';
import '../../rules/application/rules_providers.dart';
import '../../content/application/feed_progress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/shanghai_date_provider.dart';
import '../../calendar/application/calendar_providers.dart';
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

final todayFanartProvider = FutureProvider.autoDispose<List<FanartItem>>((
  ref,
) async {
  ref.watch(shanghaiDateProvider);
  final cancellation = RequestCancellation();
  ref.onDispose(cancellation.cancel);
  final repository = ref.watch(fanartRepositoryProvider);
  final rules = ref.read(rulesControllerProvider.notifier);
  final progress = FeedProgress<FanartItem>((item) => item.identity);
  final items = <FanartItem>[];
  String? cursor;
  for (var scan = 0; scan < 3; scan++) {
    final page = await repository.page(
      query: const FanartQuery(limit: 6),
      cursor: cursor,
      cancellation: cancellation,
    );
    if (cancellation.isCancelled) {
      throw const ApiFailure(ApiFailureKind.cancelled);
    }
    final accepted = progress.accept(page.items, continuation: page.nextCursor);
    items.addAll(accepted.added);
    if (page.nextCursor == null) break;
    if (accepted.stalled) {
      throw const ApiFailure(ApiFailureKind.paginationStalled);
    }
    final policy = await rules.ready();
    if (cancellation.isCancelled) {
      throw const ApiFailure(ApiFailureKind.cancelled);
    }
    if (projectFeed(items, RuleSubjects.fanart, policy).items.length >= 6) {
      break;
    }
    cursor = page.nextCursor;
  }
  return List.unmodifiable(items);
});

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
