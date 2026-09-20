import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
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

final calendarRepositoryProvider = Provider<CalendarRepository>(
  (ref) => IcsCalendarRepository(
    ref.watch(calendarDioProvider),
    calendarUrl: ref.watch(appEnvironmentProvider).calendarUrl,
  ),
);

/// The month currently shown, as its first day.
final visibleMonthProvider = StateProvider<DateTime>((ref) {
  final now = shanghaiNow();
  return DateTime.utc(now.year, now.month);
});

/// Events for the visible month, plus a margin so entries spanning a month
/// boundary are not cut off at the edges of the grid.
final monthEventsProvider = FutureProvider.family<CalendarSnapshot, DateTime>((
  ref,
  month,
) {
  final from = DateTime.utc(
    month.year,
    month.month,
  ).subtract(const Duration(days: 7));
  final until = DateTime.utc(
    month.year,
    month.month + 1,
  ).add(const Duration(days: 7));
  return ref.watch(calendarRepositoryProvider).events(from: from, until: until);
});

/// The schedule is published on the Shanghai calendar, so day grouping uses it
/// rather than the device timezone.
DateTime shanghaiNow() => DateTime.now().toUtc().add(const Duration(hours: 8));

DateTime shanghaiDayOf(DateTime instant, {required bool allDay}) {
  // An all-day value is already a pure date and must not be shifted again.
  final local = allDay
      ? instant
      : instant.toUtc().add(const Duration(hours: 8));
  return DateTime.utc(local.year, local.month, local.day);
}
