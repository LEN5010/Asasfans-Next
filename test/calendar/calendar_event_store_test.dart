import 'dart:convert';
import 'dart:typed_data';

import 'package:asasfans_next/core/storage/local_database.dart';
import 'package:asasfans_next/features/backup/data/backup_codec.dart';
import 'package:asasfans_next/features/backup/data/sqlite_backup_repository.dart';
import 'package:asasfans_next/features/calendar/data/calendar_event_store.dart';
import 'package:asasfans_next/features/calendar/domain/calendar_event.dart';
import 'package:asasfans_next/features/library/data/library_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/backup_fixture.dart';
import '../helpers/sqlite_fixture.dart';

final _calendar = Uri.parse('https://asoul.love/calendar.ics');
final _now = DateTime.utc(2026, 10, 16);
CalendarEvent _event(
  String uid,
  DateTime start, {
  int sequence = 0,
  bool allDay = false,
}) => CalendarEvent(
  uid: uid,
  title: '嘉然 $sequence',
  start: start,
  end: start.add(const Duration(hours: 2)),
  allDay: allDay,
  sequence: sequence,
);

void main() {
  late MemoryLocalDatabase db;
  late SqliteCalendarEventStore store;
  setUp(() {
    db = MemoryLocalDatabase();
    store = SqliteCalendarEventStore(db);
  });
  tearDown(() => db.close());

  test(
    'snapshot retains past events, marks missing future events and restores reappearing identities',
    () async {
      final past = _event('past', _now.subtract(const Duration(days: 7)));
      final future = _event('future', _now.add(const Duration(days: 1)));
      await store.writeSnapshot(_calendar, [past, future], _now);
      await store.writeSnapshot(
        _calendar,
        [],
        _now.add(const Duration(minutes: 1)),
      );
      expect((await store.readEvents(_calendar)).map((e) => e.uid), ['past']);
      expect(
        await store.readEvents(_calendar, includeGone: true),
        hasLength(2),
      );
      final row = db.database
          .select("SELECT gone_at FROM calendar_events WHERE uid='future'")
          .single;
      expect(
        row['gone_at'],
        _now.add(const Duration(minutes: 1)).millisecondsSinceEpoch,
      );
      await store.writeSnapshot(_calendar, [
        future.copyWith(
          start: future.start.add(const Duration(hours: 1)),
          end: future.end.add(const Duration(hours: 1)),
        ),
      ], _now.add(const Duration(minutes: 2)));
      expect((await store.readEvents(_calendar)).map((e) => e.uid), [
        'past',
        'future',
      ]);
      expect(
        (await store.readEvents(_calendar)).last.start,
        future.start.add(const Duration(hours: 1)),
      );
    },
  );

  test(
    'older SEQUENCE cannot overwrite a revision and failed fetch leaves event rows unchanged',
    () async {
      await store.writeSnapshot(
        _calendar,
        [_event('stable', _now.add(const Duration(days: 1)), sequence: 4)],
        _now,
        etag: 'good',
      );
      await store.writeSnapshot(_calendar, [
        _event('stable', _now.add(const Duration(days: 2)), sequence: 3),
      ], _now.add(const Duration(minutes: 1)));
      final before = db.database
          .select('SELECT * FROM calendar_events')
          .map((r) => Map<String, Object?>.from(r))
          .toList();
      expect((await store.readEvents(_calendar)).single.sequence, 4);
      expect(
        (await store.readEvents(_calendar)).single.start,
        _now.add(const Duration(days: 1)),
      );
      await store.failed(_calendar, _now.add(const Duration(minutes: 2)));
      expect(
        db.database
            .select('SELECT * FROM calendar_events')
            .map((r) => Map<String, Object?>.from(r))
            .toList(),
        before,
      );
      expect((await store.readSource(_calendar))!.isStale, isTrue);
    },
  );

  test('legacy v9 cache migrates atomically and drops old validators', () async {
    final old = MemoryLocalDatabase.at(9);
    addTearDown(old.close);
    old.database.execute(
      "INSERT INTO calendar_cache VALUES(?, ?, ?, 'old-etag', NULL, 0)",
      [
        _calendar.toString(),
        'BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:stable\nDTSTART:20261015T120000Z\nSUMMARY:嘉然\nEND:VEVENT\nEND:VCALENDAR',
        _now.millisecondsSinceEpoch,
      ],
    );
    final original = _event('starred', _now.subtract(const Duration(days: 20)));
    old.database.execute(
      "INSERT INTO calendar_follows(source,uid,recurrence_id,snapshot,sequence,followed_at,observed_at) VALUES(?,?,'',?,0,?,?)",
      [
        _calendar.toString(),
        original.uid,
        LibraryCodec.encodeEvent(original),
        _now.millisecondsSinceEpoch,
        _now.millisecondsSinceEpoch,
      ],
    );
    final followsBefore = old.database
        .select('SELECT * FROM calendar_follows')
        .map((row) => Map<String, Object?>.from(row))
        .toList();
    SqliteExecutor.initialize(old.database);
    expect(
      old.database
          .select('SELECT * FROM calendar_follows')
          .map((row) => Map<String, Object?>.from(row))
          .toList(),
      followsBefore,
    );
    final migrated = SqliteCalendarEventStore(old);
    expect(await migrated.migrateLegacyCache(), isTrue);
    expect((await migrated.readEvents(_calendar)).single.uid, 'stable');
    expect((await migrated.readSource(_calendar))!.etag, isNull);
    expect(
      old.database.select(
        "SELECT name FROM sqlite_master WHERE name='calendar_cache'",
      ),
      isEmpty,
    );
    expect(await migrated.migrateLegacyCache(), isTrue);
  });

  test('calendar range keeps all-day dates across device timezones', () async {
    final day = DateTime.utc(2026, 10, 17);
    final event = CalendarEvent(
      uid: 'day',
      title: '生日',
      start: day,
      end: day.add(const Duration(days: 1)),
      allDay: true,
    );
    await store.writeSnapshot(_calendar, [event], _now);
    final found = await store.readEvents(
      _calendar,
      from: DateTime.utc(2026, 10, 16, 16),
      until: DateTime.utc(2026, 10, 17, 16),
    );
    expect(found.single.start, day);
    expect(found.single.allDay, isTrue);
    expect(
      db.database
          .select('SELECT start_ms FROM calendar_events')
          .single['start_ms'],
      DateTime.utc(2026, 10, 16, 16).millisecondsSinceEpoch,
    );
  });

  test(
    'backup preserves member follows and reminder choices, excludes device calendar history',
    () async {
      await store.setMemberFollow('嘉然', true, at: _now);
      await store.writeSnapshot(_calendar, [
        _event('history', _now.subtract(const Duration(days: 1))),
      ], _now);
      await store.replaceReminders(_calendar, [
        CalendarReminderRecord(uid: 'later', fireAt: _now, notificationId: 7),
      ]);
      await db.batch(const [
        SqlStatement(
          "INSERT INTO preferences VALUES('calendar.reminders.minutes','15')",
        ),
        SqlStatement(
          "INSERT INTO preferences VALUES('calendar.reminders.enabled','true')",
        ),
      ], write: true);
      final backups = SqliteBackupRepository(db, onCommitted: () {});
      final bytes = await backups.export();
      final raw = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      expect(raw['version'], BackupCodec.formatVersion);
      final data = raw['data'] as Map<String, dynamic>;
      expect(data.containsKey('calendar_events'), isFalse);
      expect(data.containsKey('calendar_reminders'), isFalse);
      expect(data.containsKey('calendar_sources'), isFalse);
      final target = MemoryLocalDatabase();
      addTearDown(target.close);
      final localTime = _now.add(const Duration(days: 1));
      await SqliteCalendarEventStore(
        target,
      ).setMemberFollow('嘉然', true, at: localTime);
      await SqliteCalendarEventStore(
        target,
      ).setMemberFollow('贝拉', true, at: _now);
      await SqliteBackupRepository(
        target,
        onCommitted: () {},
      ).merge(await backups.inspect(bytes));
      expect(await SqliteCalendarEventStore(target).readMemberFollows(), {
        '嘉然',
        '贝拉',
      });
      expect(
        target.database
            .select(
              "SELECT followed_at FROM calendar_member_follows WHERE member='嘉然'",
            )
            .single['followed_at'],
        localTime.millisecondsSinceEpoch,
      );
      for (final version in [1, 2, 3, 4, 5, 6]) {
        expect(
          BackupCodec.decode(
            downgradeBackup(bytes, version),
          ).tables['calendar_member_follows'],
          isEmpty,
        );
      }
      final prefs = data['preferences'] as List;
      prefs.singleWhere(
        (row) => row['key'] == 'calendar.reminders.minutes',
      )['value'] = '7';
      expect(
        () => BackupCodec.decode(
          Uint8List.fromList(utf8.encode(jsonEncode(raw))),
        ),
        throwsA(isA<Exception>()),
      );
    },
  );
}
