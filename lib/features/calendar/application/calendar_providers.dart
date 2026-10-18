import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/time/local_date_provider.dart';
import '../../../core/storage/storage_providers.dart';
import '../data/calendar_cache_store.dart';
import 'calendar_follow_selection.dart';
import 'calendar_reminders.dart';
import '../../library/application/library_providers.dart';
import '../../updates/application/update_providers.dart';
import '../data/ics_calendar_repository.dart';
import '../domain/calendar_event.dart';
import '../domain/event_classifier.dart';

/// The calendar is a separate source from the metadata API, so it gets its own
/// client: no shared base URL, no credentials, independent timeouts.
final calendarDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
      followRedirects: true,
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return dio;
});

final calendarCacheStoreProvider = Provider<CalendarCacheStore>(
  (ref) => SqliteCalendarCacheStore(ref.watch(localDatabaseProvider)),
);

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  final source = ref.watch(appEnvironmentProvider).calendarUrl;
  final library = ref.watch(libraryRepositoryProvider);
  return IcsCalendarRepository(
    ref.watch(calendarDioProvider),
    calendarUrl: source,
    clock: ref.watch(currentTimeProvider),
    cacheStore: ref.watch(calendarCacheStoreProvider),
    eventStore: ref.watch(calendarEventStoreProvider),
    onSnapshot: (events, at) async {
      // Order matters: the inbox compares this snapshot against the revision
      // each follow was taken at, and synchronization is what replaces that
      // revision. Running it afterwards would compare a snapshot with itself.
      await ref
          .read(updateControllerProvider)
          .recordCalendarSnapshot(source, events);
      await library.synchronizeCalendar(source, events, at);
      await ref.read(calendarReminderControllerProvider.notifier).synchronize();
    },
  );
});

/// The month currently shown, as its first day.
final visibleMonthProvider = StateProvider<DateTime>((ref) {
  final now = ref.read(currentTimeProvider)().toLocal();
  return DateTime.utc(now.year, now.month);
});

/// Null follows today; an explicit selection remains stable across midnight.
final selectedCalendarDayProvider = StateProvider<DateTime?>((ref) => null);

/// Events for the visible month, plus a margin so entries spanning a month
/// boundary are not cut off at the edges of the grid.
final monthEventsProvider = FutureProvider.autoDispose
    .family<CalendarSnapshot, DateTime>((ref, month) async {
      final from = DateTime.utc(
        month.year,
        month.month,
      ).subtract(const Duration(days: 7));
      final until = DateTime.utc(
        month.year,
        month.month + 1,
      ).add(const Duration(days: 7));
      var disposed = false;
      Timer? expiry;
      ref.onDispose(() {
        disposed = true;
        expiry?.cancel();
      });
      final snapshot = await ref
          .watch(calendarRepositoryProvider)
          .events(from: from, until: until);
      if (!disposed && !snapshot.isStale && snapshot.expiresAt != null) {
        final remaining = snapshot.expiresAt!.difference(
          ref.read(currentTimeProvider)(),
        );
        expiry = Timer(
          remaining <= Duration.zero ? const Duration(seconds: 30) : remaining,
          ref.invalidateSelf,
        );
      }
      return snapshot;
    });

/// Refresh the underlying feed, then invalidate *all* monthly views so an old
/// cached month cannot survive a successful global calendar revalidation.
final refreshCalendarProvider = Provider<Future<void> Function(DateTime)>((
  ref,
) {
  var disposed = false;
  ref.onDispose(() => disposed = true);
  return (month) async {
    await ref
        .read(calendarRepositoryProvider)
        .events(
          from: DateTime.utc(
            month.year,
            month.month,
          ).subtract(const Duration(days: 7)),
          until: DateTime.utc(
            month.year,
            month.month + 1,
          ).add(const Duration(days: 7)),
          forceRefresh: true,
        );
    if (!disposed) ref.invalidate(monthEventsProvider);
  };
});

/// Everything followed that is still to come within 30 days, members' and
/// starred alike, soonest first; cancelled ones are left out. Read through
/// the month views, so a calendar refresh renews it as well.
final followedUpcomingProvider =
    FutureProvider.autoDispose<List<CalendarEvent>>((ref) async {
      final selection = await ref.watch(calendarFollowSelectionProvider.future);
      final source = ref.watch(appEnvironmentProvider).calendarUrl;
      final now = ref.read(currentTimeProvider)();
      final until = now.add(const Duration(days: 30));
      final last = until.toLocal();
      final months = <DateTime>[];
      for (
        var month = DateTime.utc(
          ref.watch(localDateProvider).year,
          ref.watch(localDateProvider).month,
        );
        !month.isAfter(DateTime.utc(last.year, last.month));
        month = DateTime.utc(month.year, month.month + 1)
      ) {
        months.add(month);
      }
      final snapshots = await Future.wait([
        for (final month in months)
          ref.watch(monthEventsProvider(month).future),
      ]);
      final seen = <String>{};
      return [
        for (final snapshot in snapshots)
          for (final event in snapshot.events)
            if (!event.isCancelled &&
                event.end.isAfter(now) &&
                event.start.isBefore(until) &&
                selection.contains(event, source) &&
                seen.add(event.identity))
              event,
      ]..sort((a, b) => a.start.compareTo(b.start));
    });

/// The followed lives among them, for the Today page.
final followedLivesProvider = FutureProvider.autoDispose<List<CalendarEvent>>(
  (ref) async => [
    for (final event in await ref.watch(followedUpcomingProvider.future))
      if (!event.allDay && EventClassifier.classify(event) == EventKind.live)
        event,
  ],
);
