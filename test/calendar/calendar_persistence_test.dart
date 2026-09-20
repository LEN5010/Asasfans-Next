import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/core/storage/local_database.dart';
import 'package:asasfans_next/core/storage/storage_failure.dart';
import 'package:asasfans_next/features/calendar/data/calendar_cache_store.dart';
import 'package:asasfans_next/features/calendar/data/ics_calendar_repository.dart';
import 'package:asasfans_next/features/preferences/data/sqlite_preferences_repository.dart';
import 'package:asasfans_next/features/preferences/domain/app_preferences.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_fixture.dart';

const _feed =
    'BEGIN:VCALENDAR\nVERSION:2.0\nBEGIN:VEVENT\nUID:stable\nDTSTART;TZID=Asia/Shanghai:20260921T200000\nDTEND;TZID=Asia/Shanghai:20260921T220000\nSUMMARY:嘉然歌会\nEND:VEVENT\nEND:VCALENDAR';
final _url = Uri.parse('https://asoul.love/calendar.ics');
final _from = DateTime.utc(2026, 9);
final _until = DateTime.utc(2026, 10);
final _time = DateTime.utc(2026, 9, 21, 4);

class _Adapter implements HttpClientAdapter {
  _Adapter(this.reply);
  final FutureOr<ResponseBody> Function(RequestOptions) reply;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return reply(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _ok(String body, {String etag = 'v1'}) => ResponseBody.fromString(
  body,
  200,
  headers: {
    'etag': [etag],
  },
);
ResponseBody _offline(RequestOptions options) =>
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'fixture',
    );

class _DelayedCache implements CalendarCacheStore {
  final readResult = Completer<CalendarCacheEntry?>();
  CalendarCacheEntry? saved;
  @override
  Future<CalendarCacheEntry?> read(Uri source) => readResult.future;
  @override
  Future<void> write(Uri source, CalendarCacheEntry entry) async {
    saved = entry;
  }

  @override
  Future<void> remove(Uri source) async {
    saved = null;
  }
}

class _BrokenCache implements CalendarCacheStore {
  @override
  Future<CalendarCacheEntry?> read(Uri source) async =>
      throw const StorageFailure(StorageFailureKind.unavailable);
  @override
  Future<void> write(Uri source, CalendarCacheEntry entry) async =>
      throw const StorageFailure(StorageFailureKind.unavailable);
  @override
  Future<void> remove(Uri source) async =>
      throw const StorageFailure(StorageFailureKind.unavailable);
}

void main() {
  test(
    'closing and reopening the new file permits offline calendar recovery',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'asasfans-calendar-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/personal.sqlite3';
      final firstStore = IsolateLocalDatabase(() async => path);
      final online = _Adapter((_) => _ok(_feed));
      final first = IcsCalendarRepository(
        Dio()..httpClientAdapter = online,
        calendarUrl: _url,
        clock: () => _time,
        cacheStore: SqliteCalendarCacheStore(firstStore),
      );
      await first.events(from: _from, until: _until);
      await firstStore.close();

      final reopened = IsolateLocalDatabase(() async => path);
      addTearDown(reopened.close);
      final offline = _Adapter(_offline);
      final second = IcsCalendarRepository(
        Dio()..httpClientAdapter = offline,
        calendarUrl: _url,
        clock: () => _time.add(const Duration(hours: 1)),
        cacheStore: SqliteCalendarCacheStore(reopened),
      );
      final snapshot = await second.events(from: _from, until: _until);
      expect(snapshot.events.single.title, '嘉然歌会');
      expect(snapshot.events.single.start, DateTime.utc(2026, 9, 21, 12));
      expect(snapshot.isStale, isTrue);
      expect(snapshot.fetchedAt, _time);
      expect(snapshot.offlineCacheUnavailable, isFalse);
      expect(offline.requests.single.headers['If-None-Match'], 'v1');
      expect(
        (await SqliteCalendarCacheStore(reopened).read(_url))!.stale,
        isTrue,
      );
    },
  );

  test(
    'healthy disk hits respect TTL; forced 304 persists a new validation time',
    () async {
      final db = MemoryLocalDatabase();
      addTearDown(db.close);
      final cache = SqliteCalendarCacheStore(db);
      await cache.write(
        _url,
        CalendarCacheEntry(body: _feed, fetchedAt: _time, etag: 'v1'),
      );
      final adapter = _Adapter(
        (_) => ResponseBody.fromString(
          '',
          304,
          headers: {
            'etag': ['v2'],
          },
        ),
      );
      final now = _time.add(const Duration(minutes: 1));
      final repo = IcsCalendarRepository(
        Dio()..httpClientAdapter = adapter,
        calendarUrl: _url,
        clock: () => now,
        cacheStore: cache,
      );
      final cached = await repo.events(from: _from, until: _until);
      expect(adapter.requests, isEmpty);
      expect(cached.fromCache, isTrue);
      expect(cached.isStale, isFalse);
      await repo.events(from: _from, until: _until, forceRefresh: true);
      final saved = (await cache.read(_url))!;
      expect(saved.body, _feed);
      expect(saved.fetchedAt, now);
      expect(saved.etag, 'v2');
    },
  );

  test(
    'force refresh racing disk hydration cannot be swallowed by a cache hit',
    () async {
      final cache = _DelayedCache();
      final adapter = _Adapter((_) => _ok(_feed.replaceAll('嘉然歌会', '改期安排')));
      final repo = IcsCalendarRepository(
        Dio()..httpClientAdapter = adapter,
        calendarUrl: _url,
        clock: () => _time,
        cacheStore: cache,
      );
      final initial = repo.events(from: _from, until: _until);
      final forced = repo.events(
        from: _from,
        until: _until,
        forceRefresh: true,
      );
      cache.readResult.complete(
        CalendarCacheEntry(body: _feed, fetchedAt: _time, etag: 'old'),
      );
      expect((await initial).events.single.title, '嘉然歌会');
      expect((await forced).events.single.title, '改期安排');
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.headers['If-None-Match'], 'old');
      expect(cache.saved!.body, contains('改期安排'));
    },
  );

  test(
    'corrupt cached ICS is removed without resetting personal preferences',
    () async {
      final db = MemoryLocalDatabase();
      addTearDown(db.close);
      final cache = SqliteCalendarCacheStore(db);
      await SqlitePreferencesRepository(db).setAppearance(AppAppearance.dark);
      await cache.write(
        _url,
        CalendarCacheEntry(
          body: '<html>not a calendar</html>',
          fetchedAt: _time,
          etag: 'bad',
        ),
      );
      final adapter = _Adapter(_offline);
      final repo = IcsCalendarRepository(
        Dio()..httpClientAdapter = adapter,
        calendarUrl: _url,
        clock: () => _time,
        cacheStore: cache,
      );
      await expectLater(
        repo.events(from: _from, until: _until),
        throwsA(isA<ApiFailure>()),
      );
      expect(await cache.read(_url), isNull);
      expect(adapter.requests.single.headers['If-None-Match'], isNull);
      expect(
        (await SqlitePreferencesRepository(db).load()).appearance,
        AppAppearance.dark,
      );
    },
  );

  test(
    'legitimately empty responses replace disk content, but malformed ones do not',
    () async {
      final db = MemoryLocalDatabase();
      addTearDown(db.close);
      final cache = SqliteCalendarCacheStore(db);
      await cache.write(
        _url,
        CalendarCacheEntry(body: _feed, fetchedAt: _time, etag: 'good'),
      );
      final broken = IcsCalendarRepository(
        Dio()..httpClientAdapter = _Adapter((_) => _ok('html', etag: 'bad')),
        calendarUrl: _url,
        clock: () => _time,
        cacheStore: cache,
      );
      expect(
        (await broken.events(
          from: _from,
          until: _until,
          forceRefresh: true,
        )).isStale,
        isTrue,
      );
      expect((await cache.read(_url))!.etag, 'good');
      const empty = 'BEGIN:VCALENDAR\nVERSION:2.0\nEND:VCALENDAR';
      final clearing = IcsCalendarRepository(
        Dio()..httpClientAdapter = _Adapter((_) => _ok(empty, etag: 'empty')),
        calendarUrl: _url,
        clock: () => _time,
        cacheStore: cache,
      );
      expect(
        (await clearing.events(
          from: _from,
          until: _until,
          forceRefresh: true,
        )).events,
        isEmpty,
      );
      final restarted = IcsCalendarRepository(
        Dio()..httpClientAdapter = _Adapter(_offline),
        calendarUrl: _url,
        clock: () => _time,
        cacheStore: cache,
      );
      expect(
        (await restarted.events(from: _from, until: _until)).events,
        isEmpty,
      );
    },
  );

  test(
    'failed disk persistence still displays fresh network data without claiming offline readiness',
    () async {
      final repo = IcsCalendarRepository(
        Dio()..httpClientAdapter = _Adapter((_) => _ok(_feed)),
        calendarUrl: _url,
        clock: () => _time,
        cacheStore: _BrokenCache(),
      );
      final snapshot = await repo.events(from: _from, until: _until);
      expect(snapshot.events, hasLength(1));
      expect(snapshot.isStale, isFalse);
      expect(snapshot.offlineCacheUnavailable, isTrue);
    },
  );

  test('changing source never sends another calendar validators', () async {
    final db = MemoryLocalDatabase();
    addTearDown(db.close);
    final cache = SqliteCalendarCacheStore(db);
    await cache.write(
      _url,
      CalendarCacheEntry(
        body: _feed,
        fetchedAt: _time,
        etag: 'private-to-original-source',
      ),
    );
    final adapter = _Adapter((_) => _ok(_feed));
    final repo = IcsCalendarRepository(
      Dio()..httpClientAdapter = adapter,
      calendarUrl: Uri.parse('https://different.example/calendar.ics'),
      clock: () => _time,
      cacheStore: cache,
    );
    await repo.events(from: _from, until: _until);
    expect(adapter.requests.single.headers['If-None-Match'], isNull);
  });
}
