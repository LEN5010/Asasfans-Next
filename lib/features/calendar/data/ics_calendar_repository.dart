import 'package:dio/dio.dart';

import '../../../core/network/api_failure.dart';
import '../domain/calendar_event.dart';
import 'ics_parser.dart';
import 'calendar_cache_store.dart';

/// Independent, credential-free ICS transport with single-flight revalidation.
class IcsCalendarRepository implements CalendarRepository {
  IcsCalendarRepository(
    this._dio, {
    required this.calendarUrl,
    this.ttl = const Duration(minutes: 30),
    DateTime Function()? clock,
    CalendarCacheStore? cacheStore,
    Future<void> Function(List<CalendarEvent>, DateTime)? onSnapshot,
  }) : _clock = clock ?? DateTime.now,
       _cacheStore = cacheStore,
       _onSnapshot = onSnapshot;

  final Dio _dio;
  final Uri calendarUrl;
  final Duration ttl;
  final DateTime Function() _clock;
  final CalendarCacheStore? _cacheStore;
  final Future<void> Function(List<CalendarEvent>, DateTime)? _onSnapshot;
  bool _hydrated = false;
  String? _body;
  bool _offlineCacheUnavailable = false;
  List<CalendarEvent>? _cached;
  DateTime? _fetchedAt;
  String? _etag;
  String? _lastModified;
  bool _revalidationFailed = false;
  DateTime? _retryAt;
  _CalendarLoad? _inFlight;

  @override
  Future<CalendarSnapshot> events({
    required DateTime from,
    required DateTime until,
    bool forceRefresh = false,
  }) async {
    final snapshot = await _load(forceRefresh: forceRefresh);
    return CalendarSnapshot(
      events: List.unmodifiable(
        snapshot.events.where((e) => overlaps(e, from, until)),
      ),
      fetchedAt: snapshot.fetchedAt,
      fromCache: snapshot.fromCache,
      isStale: snapshot.isStale,
      expiresAt: snapshot.expiresAt,
      offlineCacheUnavailable: snapshot.offlineCacheUnavailable,
      followSyncUnavailable: snapshot.followSyncUnavailable,
    );
  }

  static bool overlaps(CalendarEvent event, DateTime from, DateTime until) =>
      event.start.isBefore(until) && event.end.isAfter(from);

  CalendarSnapshot _snapshot({bool fromCache = false}) => CalendarSnapshot(
    events: _cached!,
    fetchedAt: _fetchedAt!,
    fromCache: fromCache,
    isStale: _revalidationFailed,
    expiresAt: _fetchedAt!.add(ttl),
    offlineCacheUnavailable: _offlineCacheUnavailable,
  );

  Future<CalendarSnapshot> _load({required bool forceRefresh}) async {
    final pending = _inFlight;
    if (pending != null) {
      final snapshot = await pending.future;
      if (!forceRefresh || pending.revalidated) return snapshot;
      // A force request arriving during disk hydration must not be satisfied
      // by a fresh cache hit that never reached the source.
      if (identical(_inFlight, pending)) _inFlight = null;
      return _load(forceRefresh: true);
    }
    final request = _CalendarLoad();
    _inFlight = request;
    request.future = _loadHydrated(request, forceRefresh: forceRefresh);
    try {
      return await request.future;
    } finally {
      if (identical(_inFlight, request)) _inFlight = null;
    }
  }

  Future<CalendarSnapshot> _loadHydrated(
    _CalendarLoad request, {
    required bool forceRefresh,
  }) async {
    await _hydrate();
    final now = _clock();
    final hasCache = _cached != null && _fetchedAt != null;
    final fresh =
        hasCache && !_revalidationFailed && now.isBefore(_fetchedAt!.add(ttl));
    final backingOff = _retryAt != null && now.isBefore(_retryAt!);
    if (hasCache && !forceRefresh && (fresh || backingOff)) {
      return _observe(_snapshot(fromCache: true));
    }
    request.revalidated = true;
    return _observe(await _fetch());
  }

  Future<CalendarSnapshot> _observe(CalendarSnapshot snapshot) async {
    var failed = false;
    try {
      await _onSnapshot?.call(snapshot.events, snapshot.fetchedAt);
    } catch (_) {
      failed = true;
    }
    return CalendarSnapshot(
      events: snapshot.events,
      fetchedAt: snapshot.fetchedAt,
      fromCache: snapshot.fromCache,
      isStale: snapshot.isStale,
      expiresAt: snapshot.expiresAt,
      offlineCacheUnavailable: snapshot.offlineCacheUnavailable,
      followSyncUnavailable: failed,
    );
  }

  Future<void> _hydrate() async {
    if (_hydrated) return;
    _hydrated = true;
    final store = _cacheStore;
    if (store == null) return;
    try {
      final entry = await store.read(calendarUrl);
      if (entry == null) return;
      if (entry.body.length > SqliteCalendarCacheStore.maxBodyCharacters) {
        throw const FormatException('cache size');
      }
      final parsed = IcsParser.parse(entry.body);
      _body = entry.body;
      _cached = parsed;
      _fetchedAt = entry.fetchedAt;
      _etag = entry.etag;
      _lastModified = entry.lastModified;
      _revalidationFailed = entry.stale || entry.fetchedAt.isAfter(_clock());
    } on FormatException {
      // A malformed cache is disposable; deleting it never touches personal
      // tables or the original Android databases.
      try {
        await store.remove(calendarUrl);
      } catch (_) {
        _offlineCacheUnavailable = true;
      }
    } catch (_) {
      _offlineCacheUnavailable = true;
    }
  }

  Future<void> _persist() async {
    final store = _cacheStore;
    if (store == null || _body == null || _fetchedAt == null) return;
    try {
      await store.write(
        calendarUrl,
        CalendarCacheEntry(
          body: _body!,
          fetchedAt: _fetchedAt!,
          etag: _etag,
          lastModified: _lastModified,
          stale: _revalidationFailed,
        ),
      );
      _offlineCacheUnavailable = false;
    } catch (_) {
      // A storage failure must not erase a good network response, nor claim
      // that the response is available after a restart.
      _offlineCacheUnavailable = true;
    }
  }

  Future<CalendarSnapshot> _fetch() async {
    try {
      final response = await _dio.getUri<String>(
        calendarUrl,
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            'User-Agent': 'asasfans',
            if (_etag != null) 'If-None-Match': _etag,
            if (_lastModified != null) 'If-Modified-Since': _lastModified,
          },
          validateStatus: (status) => status == 200 || status == 304,
        ),
      );
      if (response.statusCode == 304) {
        if (_cached == null) {
          throw const ApiFailure(ApiFailureKind.invalidResponse);
        }
        // A 304 can update validators, but omission preserves the previous ones.
        _etag = response.headers.value('etag') ?? _etag;
        _lastModified =
            response.headers.value('last-modified') ?? _lastModified;
      } else {
        final body = response.data;
        if (body == null ||
            body.length > SqliteCalendarCacheStore.maxBodyCharacters) {
          throw const ApiFailure(ApiFailureKind.invalidResponse);
        }
        final parsed = IcsParser.parse(body);
        // Parsing distinguishes a valid empty calendar from malformed data.
        // Publish data and validators together only after successful decoding.
        _cached = parsed;
        _body = body;
        _etag = response.headers.value('etag');
        _lastModified = response.headers.value('last-modified');
      }
      _fetchedAt = _clock();
      _revalidationFailed = false;
      _retryAt = null;
      await _persist();
      return _snapshot();
    } on FormatException {
      return _fallback(const ApiFailure(ApiFailureKind.invalidResponse));
    } on ApiFailure catch (failure) {
      return _fallback(failure);
    } on DioException catch (error) {
      return _fallback(_map(error));
    }
  }

  Future<CalendarSnapshot> _fallback(ApiFailure failure) async {
    if (_cached == null || _fetchedAt == null) throw failure;
    _revalidationFailed = true;
    // Invalidation after a manual refresh must not immediately redownload the
    // same failing source. A later explicit retry can bypass this soft delay.
    _retryAt = _clock().add(const Duration(seconds: 30));
    await _persist();
    return _snapshot(fromCache: true);
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

class _CalendarLoad {
  late final Future<CalendarSnapshot> future;
  bool revalidated = false;
}
