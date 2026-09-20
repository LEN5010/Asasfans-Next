import 'dart:typed_data';

import 'package:asasfans_next/features/calendar/data/ics_calendar_repository.dart';
import 'package:asasfans_next/features/calendar/domain/calendar_event.dart';
import 'package:asasfans_next/features/library/data/sqlite_library_repository.dart';
import 'package:asasfans_next/features/library/domain/library_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_fixture.dart';

class _Feed implements HttpClientAdapter {
  String body =
      'BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:stable\nSEQUENCE:1\nDTSTART:20261002T120000Z\nDTEND:20261002T140000Z\nSUMMARY:改期到十月\nEND:VEVENT\nEND:VCALENDAR';
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(body, 200);
  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'full-source observer updates followed events even if they moved outside the visible month',
    () async {
      final db = MemoryLocalDatabase();
      final library = SqliteLibraryRepository(db);
      addTearDown(() async {
        await library.close();
        await db.close();
      });
      final url = Uri.parse('https://fixture.example/calendar.ics');
      final original = CalendarEvent(
        uid: 'stable',
        title: '九月旧安排',
        start: DateTime.utc(2026, 9, 21, 12),
        end: DateTime.utc(2026, 9, 21, 14),
        allDay: false,
      );
      await library.followCalendar(
        CalendarFollowKey(source: url, uid: 'stable'),
        original,
      );
      final adapter = _Feed();
      var now = DateTime.utc(2026, 9, 21);
      final calendar = IcsCalendarRepository(
        Dio()..httpClientAdapter = adapter,
        calendarUrl: url,
        clock: () => now,
        onSnapshot: (events, at) =>
            library.synchronizeCalendar(url, events, at),
      );
      final month = await calendar.events(
        from: DateTime.utc(2026, 9),
        until: DateTime.utc(2026, 10),
      );
      expect(month.events, isEmpty);
      expect((await library.calendarFollows()).single.event.start.month, 10);
      adapter.body = adapter.body.replaceAll(
        'SEQUENCE:1',
        'SEQUENCE:2\nSTATUS:CANCELLED',
      );
      now = now.add(const Duration(minutes: 1));
      await calendar.events(
        from: DateTime.utc(2026, 9),
        until: DateTime.utc(2026, 10),
        forceRefresh: true,
      );
      expect(
        (await library.calendarFollows()).single.event.isCancelled,
        isTrue,
      );
      adapter.body = 'BEGIN:VCALENDAR\nVERSION:2.0\nEND:VCALENDAR';
      now = now.add(const Duration(minutes: 1));
      await calendar.events(
        from: DateTime.utc(2026, 9),
        until: DateTime.utc(2026, 10),
        forceRefresh: true,
      );
      expect(await library.calendarFollows(), hasLength(1));
    },
  );
  test(
    'personal-store failure does not discard fresh public calendar content',
    () async {
      final calendar = IcsCalendarRepository(
        Dio()..httpClientAdapter = _Feed(),
        calendarUrl: Uri.parse('https://fixture.example/calendar.ics'),
        onSnapshot: (_, _) async => throw StateError('fixture'),
      );
      final snapshot = await calendar.events(
        from: DateTime.utc(2026, 10),
        until: DateTime.utc(2026, 11),
      );
      expect(snapshot.events, hasLength(1));
      expect(snapshot.followSyncUnavailable, isTrue);
      expect(snapshot.isStale, isFalse);
    },
  );
}
