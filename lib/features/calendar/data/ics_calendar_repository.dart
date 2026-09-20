import 'package:dio/dio.dart';

import '../../../core/network/api_failure.dart';
import '../domain/calendar_event.dart';
import 'ics_parser.dart';

/// Reads the published ICS feed.
///
/// The calendar is a separate source from the metadata API: it gets its own
/// client, carries no credentials, and its failures never affect content.
class IcsCalendarRepository implements CalendarRepository {
  IcsCalendarRepository(
    this._dio, {
    required this.calendarUrl,
    this.ttl = const Duration(minutes: 30),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Dio _dio;
  final Uri calendarUrl;
  final Duration ttl;
  final DateTime Function() _clock;

  List<CalendarEvent>? _cached;
  DateTime? _fetchedAt;
  String? _etag;
  String? _lastModified;

  @override
  Future<CalendarSnapshot> events({
    required DateTime from,
    required DateTime until,
    bool forceRefresh = false,
  }) async {
    final snapshot = await _load(forceRefresh: forceRefresh);
    return CalendarSnapshot(
      events: List.unmodifiable(
        snapshot.events.where((event) => overlaps(event, from, until)),
      ),
      fetchedAt: snapshot.fetchedAt,
      fromCache: snapshot.fromCache,
    );
  }

  /// An event belongs to a range when it overlaps it at all, because DTEND is
  /// exclusive and a long event may start before the window opens.
  static bool overlaps(CalendarEvent event, DateTime from, DateTime until) =>
      event.start.isBefore(until) && event.end.isAfter(from);

  Future<CalendarSnapshot> _load({required bool forceRefresh}) async {
    final cached = _cached;
    final fetchedAt = _fetchedAt;
    final fresh =
        cached != null &&
        fetchedAt != null &&
        _clock().difference(fetchedAt) < ttl;
    if (fresh && !forceRefresh) {
      return CalendarSnapshot(
        events: cached,
        fetchedAt: fetchedAt,
        fromCache: true,
      );
    }

    try {
      final response = await _dio.getUri<String>(
        calendarUrl,
        options: Options(
          responseType: ResponseType.plain,
          // Identify the client the way the existing consumer does.
          headers: {
            'User-Agent': 'asasfans',
            if (_etag != null) 'If-None-Match': _etag,
            if (_lastModified != null) 'If-Modified-Since': _lastModified,
          },
          // 304 is a successful answer, not a failure.
          validateStatus: (status) =>
              status != null && (status == 304 || status < 400),
        ),
      );

      if (response.statusCode == 304 && cached != null) {
        _fetchedAt = _clock();
        return CalendarSnapshot(events: cached, fetchedAt: _fetchedAt!);
      }

      final body = response.data;
      final parsed = body == null || body.isEmpty
          ? const <CalendarEvent>[]
          : IcsParser.parse(body);
      // An unusable body must not replace good data with nothing, and must not
      // update the validators either, or the next revalidation would confirm
      // the broken response.
      if (parsed.isEmpty && cached != null && cached.isNotEmpty) {
        return CalendarSnapshot(
          events: cached,
          fetchedAt: fetchedAt ?? _clock(),
          fromCache: true,
        );
      }
      if (parsed.isEmpty && (body == null || body.isEmpty)) {
        throw const ApiFailure(ApiFailureKind.invalidResponse);
      }
      _etag = response.headers.value('etag');
      _lastModified = response.headers.value('last-modified');
      _cached = parsed;
      _fetchedAt = _clock();
      return CalendarSnapshot(events: parsed, fetchedAt: _fetchedAt!);
    } on DioException catch (error) {
      final failure = _map(error);
      // A stale calendar is more useful than an error screen.
      if (cached != null && fetchedAt != null) {
        return CalendarSnapshot(
          events: cached,
          fetchedAt: fetchedAt,
          fromCache: true,
        );
      }
      throw failure;
    }
  }

  static ApiFailure _map(DioException error) {
    if (error.type == DioExceptionType.cancel) {
      return const ApiFailure(ApiFailureKind.cancelled);
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const ApiFailure(ApiFailureKind.timeout);
    }
    final status = error.response?.statusCode;
    if (status == null) return const ApiFailure(ApiFailureKind.offline);
    if (status >= 500) return const ApiFailure(ApiFailureKind.unavailable);
    return const ApiFailure(ApiFailureKind.invalidResponse);
  }
}
