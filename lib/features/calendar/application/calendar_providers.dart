import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/time/calendar_time.dart';
import '../../../core/time/shanghai_date_provider.dart';
import '../../../core/storage/storage_providers.dart';
import '../data/calendar_cache_store.dart';
import '../../library/application/library_providers.dart';
import '../data/ics_calendar_repository.dart';
import '../domain/calendar_event.dart';

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
    onSnapshot: (events, at) => library.synchronizeCalendar(source, events, at),
  );
});

/// The month currently shown, as its first day.
final visibleMonthProvider = StateProvider<DateTime>((ref) {
  final now = CalendarTime.inShanghai(ref.read(currentTimeProvider)());
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

/// The schedule is published on the Shanghai calendar, so day grouping uses it
/// rather than the device timezone.
DateTime shanghaiNow() => CalendarTime.inShanghai(DateTime.now());

DateTime shanghaiDayOf(DateTime instant, {required bool allDay}) =>
    CalendarTime.dayOf(instant, allDay: allDay);

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
