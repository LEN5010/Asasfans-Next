import 'dart:typed_data';

import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/calendar/data/ics_calendar_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const _feed =
    'BEGIN:VCALENDAR\r\n'
    'BEGIN:VEVENT\r\nUID:1\r\nDTSTART:20260921T120000Z\r\n'
    'DTEND:20260921T140000Z\r\nSUMMARY:直播\r\nEND:VEVENT\r\n'
    'BEGIN:VEVENT\r\nUID:2\r\nDTSTART:20261001T120000Z\r\n'
    'SUMMARY:下个月\r\nEND:VEVENT\r\n'
    'END:VCALENDAR\r\n';

/// Serves scripted responses and records the conditional headers sent.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.responses);
  final List<ResponseBody Function()> responses;
  final List<RequestOptions> requests = [];
  int index = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final build = responses[index.clamp(0, responses.length - 1)];
    index++;
    return build();
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _ok(String body, {Map<String, List<String>>? headers}) =>
    ResponseBody.fromString(body, 200, headers: headers ?? const {});

Dio _dio(_Adapter adapter) => Dio()..httpClientAdapter = adapter;

void main() {
  final url = Uri.parse('https://asoul.love/calendar.ics');
  final windowStart = DateTime.utc(2026, 9, 1);
  final windowEnd = DateTime.utc(2026, 9, 30);

  test('identifies itself and sends no credentials', () async {
    final adapter = _Adapter([() => _ok(_feed)]);
    final repository = IcsCalendarRepository(_dio(adapter), calendarUrl: url);

    await repository.events(from: windowStart, until: windowEnd);

    expect(adapter.requests.single.headers['User-Agent'], 'asasfans');
    expect(
      adapter.requests.single.headers.keys.map((k) => k.toLowerCase()),
      isNot(contains('cookie')),
    );
  });

  test('returns only events overlapping the requested window', () async {
    final repository = IcsCalendarRepository(
      _dio(_Adapter([() => _ok(_feed)])),
      calendarUrl: url,
    );

    final snapshot = await repository.events(
      from: windowStart,
      until: windowEnd,
    );

    expect(snapshot.events.map((e) => e.uid), ['1']);
  });

  test('an event spanning the window edge is included', () async {
    const spanning =
        'BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:long\r\n'
        'DTSTART:20260830T120000Z\r\nDTEND:20260902T120000Z\r\n'
        'END:VEVENT\r\nEND:VCALENDAR\r\n';
    final repository = IcsCalendarRepository(
      _dio(_Adapter([() => _ok(spanning)])),
      calendarUrl: url,
    );

    final snapshot = await repository.events(
      from: windowStart,
      until: windowEnd,
    );

    expect(snapshot.events, hasLength(1));
  });

  test('a second read inside the TTL does not hit the network', () async {
    final adapter = _Adapter([() => _ok(_feed)]);
    final repository = IcsCalendarRepository(
      _dio(adapter),
      calendarUrl: url,
      clock: () => DateTime.utc(2026, 9, 21, 12),
    );

    await repository.events(from: windowStart, until: windowEnd);
    final second = await repository.events(from: windowStart, until: windowEnd);

    expect(adapter.requests, hasLength(1));
    expect(second.fromCache, isTrue);
  });

  test('a conditional revalidation reuses the cached events on 304', () async {
    var now = DateTime.utc(2026, 9, 21, 12);
    final adapter = _Adapter([
      () => _ok(
        _feed,
        headers: {
          'etag': ['"v1"'],
        },
      ),
      () => ResponseBody.fromString('', 304),
    ]);
    final repository = IcsCalendarRepository(
      _dio(adapter),
      calendarUrl: url,
      clock: () => now,
    );

    await repository.events(from: windowStart, until: windowEnd);
    now = now.add(const Duration(hours: 2));
    final second = await repository.events(from: windowStart, until: windowEnd);

    expect(adapter.requests.last.headers['If-None-Match'], '"v1"');
    expect(second.events.map((e) => e.uid), ['1']);
  });

  test('a network failure serves the last good calendar as stale', () async {
    var now = DateTime.utc(2026, 9, 21, 12);
    final adapter = _Adapter([
      () => _ok(_feed),
      () => throw DioException.connectionError(
        requestOptions: RequestOptions(),
        reason: 'offline',
      ),
    ]);
    final repository = IcsCalendarRepository(
      _dio(adapter),
      calendarUrl: url,
      clock: () => now,
    );

    final first = await repository.events(from: windowStart, until: windowEnd);
    now = now.add(const Duration(hours: 2));
    final second = await repository.events(from: windowStart, until: windowEnd);

    expect(second.events.map((e) => e.uid), ['1']);
    expect(second.fromCache, isTrue);
    // The stale marker lets the UI say when it last synced.
    expect(second.fetchedAt, first.fetchedAt);
  });

  test('a failure with no cached calendar surfaces the error', () async {
    final repository = IcsCalendarRepository(
      _dio(
        _Adapter([
          () => throw DioException.connectionError(
            requestOptions: RequestOptions(),
            reason: 'offline',
          ),
        ]),
      ),
      calendarUrl: url,
    );

    await expectLater(
      repository.events(from: windowStart, until: windowEnd),
      throwsA(isA<ApiFailure>()),
    );
  });

  test('a non-calendar body does not replace good data with nothing', () async {
    var now = DateTime.utc(2026, 9, 21, 12);
    final repository = IcsCalendarRepository(
      _dio(_Adapter([() => _ok(_feed), () => _ok('<html>error page</html>')])),
      calendarUrl: url,
      clock: () => now,
    );

    await repository.events(from: windowStart, until: windowEnd);
    now = now.add(const Duration(hours: 2));
    final second = await repository.events(from: windowStart, until: windowEnd);

    expect(second.events.map((e) => e.uid), ['1']);
  });

  test('forceRefresh bypasses a still-fresh cache', () async {
    final adapter = _Adapter([() => _ok(_feed)]);
    final repository = IcsCalendarRepository(
      _dio(adapter),
      calendarUrl: url,
      clock: () => DateTime.utc(2026, 9, 21, 12),
    );

    await repository.events(from: windowStart, until: windowEnd);
    await repository.events(
      from: windowStart,
      until: windowEnd,
      forceRefresh: true,
    );

    expect(adapter.requests, hasLength(2));
  });
}
