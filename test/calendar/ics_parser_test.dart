import 'package:asasfans_next/features/calendar/data/ics_parser.dart';
import 'package:asasfans_next/features/calendar/domain/calendar_event.dart';
import 'package:flutter_test/flutter_test.dart';

String _calendar(String body) =>
    'BEGIN:VCALENDAR\r\nVERSION:2.0\r\n$body\r\nEND:VCALENDAR\r\n';

void main() {
  test('joins folded lines back into one value', () {
    final events = IcsParser.parse(
      _calendar(
        'BEGIN:VEVENT\r\n'
        'UID:1\r\n'
        'DTSTART:20260921T120000Z\r\n'
        'SUMMARY:嘉然的生日会\r\n'
        ' 直播特别节目\r\n'
        'END:VEVENT',
      ),
    );

    expect(events.single.title, '嘉然的生日会直播特别节目');
  });

  test('decodes escaped text without mangling backslashes', () {
    final events = IcsParser.parse(
      _calendar(
        'BEGIN:VEVENT\r\n'
        'UID:1\r\n'
        'DTSTART:20260921T120000Z\r\n'
        r'SUMMARY:歌会\, 杂谈\; 第二场'
        '\r\n'
        r'DESCRIPTION:第一行\n第二行\\结束'
        '\r\n'
        'END:VEVENT',
      ),
    );

    expect(events.single.title, '歌会, 杂谈; 第二场');
    expect(events.single.description, '第一行\n第二行\\结束');
  });

  test('a quoted parameter containing a colon does not split the line', () {
    final line = IcsParser.parseLine(
      'DTSTART;TZID="Asia/Shanghai:x":20260921T120000',
    );
    expect(line?.name, 'DTSTART');
    expect(line?.params['TZID'], 'Asia/Shanghai:x');
    expect(line?.value, '20260921T120000');
  });

  test('UTC and named-zone stamps resolve to source instants', () {
    final utc = IcsParser.parseDateTime('20260921T120000Z', const {});
    expect(utc!.value.isUtc, isTrue);
    expect(utc.value, DateTime.utc(2026, 9, 21, 12));

    final floating = IcsParser.parseDateTime('20260921T120000', const {
      'TZID': 'Asia/Shanghai',
    });
    expect(floating!.value, DateTime.utc(2026, 9, 21, 4));
    expect(floating.value.isUtc, isTrue);
    expect(floating.tzid, 'Asia/Shanghai');
    expect(floating.isDate, isFalse);
  });

  test('an all-day date is a pure date, not a local midnight instant', () {
    final events = IcsParser.parse(
      _calendar(
        'BEGIN:VEVENT\r\n'
        'UID:birthday\r\n'
        'DTSTART;VALUE=DATE:20261022\r\n'
        'DTEND;VALUE=DATE:20261023\r\n'
        'SUMMARY:嘉然生日\r\n'
        'END:VEVENT',
      ),
    );

    final event = events.single;
    expect(event.allDay, isTrue);
    expect(event.start, DateTime.utc(2026, 10, 22));
    // DTEND is exclusive, so a one-day event ends at the next day's start.
    expect(event.end, DateTime.utc(2026, 10, 23));
  });

  test('a multi-day all-day range keeps its exclusive end', () {
    final events = IcsParser.parse(
      _calendar(
        'BEGIN:VEVENT\r\n'
        'UID:week\r\n'
        'DTSTART;VALUE=DATE:20261019\r\n'
        'DTEND;VALUE=DATE:20261026\r\n'
        'END:VEVENT',
      ),
    );

    expect(events.single.end.difference(events.single.start).inDays, 7);
  });

  test('DURATION is used when DTEND is absent', () {
    final events = IcsParser.parse(
      _calendar(
        'BEGIN:VEVENT\r\n'
        'UID:1\r\n'
        'DTSTART:20260921T120000Z\r\n'
        'DURATION:PT2H30M\r\n'
        'END:VEVENT',
      ),
    );

    expect(events.single.end, DateTime.utc(2026, 9, 21, 14, 30));
  });

  test('parses week, day and negative durations', () {
    expect(IcsParser.parseDuration('P1W'), const Duration(days: 7));
    expect(
      IcsParser.parseDuration('P1DT2H'),
      const Duration(days: 1, hours: 2),
    );
    expect(IcsParser.parseDuration('-PT30M'), const Duration(minutes: -30));
    expect(IcsParser.parseDuration('nonsense'), isNull);
  });

  test('an end at or before the start is repaired, not kept inverted', () {
    final events = IcsParser.parse(
      _calendar(
        'BEGIN:VEVENT\r\n'
        'UID:1\r\n'
        'DTSTART:20260921T120000Z\r\n'
        'DTEND:20260921T100000Z\r\n'
        'END:VEVENT',
      ),
    );

    expect(events.single.end.isAfter(events.single.start), isTrue);
  });

  test('cancellation and revision survive parsing', () {
    final events = IcsParser.parse(
      _calendar(
        'BEGIN:VEVENT\r\n'
        'UID:1\r\n'
        'DTSTART:20260921T120000Z\r\n'
        'STATUS:CANCELLED\r\n'
        'SEQUENCE:3\r\n'
        'END:VEVENT',
      ),
    );

    expect(events.single.status, EventStatus.cancelled);
    expect(events.single.isCancelled, isTrue);
    expect(events.single.sequence, 3);
  });

  test('a recurrence override has its own identity under a shared uid', () {
    final events = IcsParser.parse(
      _calendar(
        'BEGIN:VEVENT\r\n'
        'UID:series\r\n'
        'DTSTART:20260921T120000Z\r\n'
        'END:VEVENT\r\n'
        'BEGIN:VEVENT\r\n'
        'UID:series\r\n'
        'RECURRENCE-ID:20260928T120000Z\r\n'
        'DTSTART:20260928T140000Z\r\n'
        'END:VEVENT',
      ),
    );

    expect(events.map((e) => e.uid).toSet(), {'series'});
    expect(events.first.identity, '["series",null]');
    expect(events.last.identity, '["series","20260928T120000Z"]');
    expect(events.first.identity, isNot(events.last.identity));
  });

  test('rescheduling keeps the occupancy identity stable', () {
    final events = IcsParser.parse(
      _calendar(
        'BEGIN:VEVENT\r\n'
        'UID:1\r\n'
        'DTSTART:20260921T120000Z\r\n'
        'END:VEVENT',
      ),
    );

    final moved = events.single.copyWith(start: DateTime.utc(2026, 9, 21, 20));
    // A reminder keyed on identity is updated rather than duplicated.
    expect(moved.identity, events.single.identity);
    expect(moved.start, isNot(events.single.start));
  });

  test('categories become a real list', () {
    final events = IcsParser.parse(
      _calendar(
        'BEGIN:VEVENT\r\n'
        'UID:1\r\n'
        'DTSTART:20260921T120000Z\r\n'
        'CATEGORIES:直播,歌会\r\n'
        'END:VEVENT',
      ),
    );

    expect(events.single.categories, ['直播', '歌会']);
  });

  test(
    'an invalid event does not silently turn a feed into an empty calendar',
    () {
      expect(
        () => IcsParser.parse(
          _calendar('BEGIN:VEVENT\r\nUID:1\r\nSUMMARY:无开始时间\r\nEND:VEVENT'),
        ),
        throwsFormatException,
      );
    },
  );

  test('bare LF line endings parse the same as CRLF', () {
    final events = IcsParser.parse(
      'BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:1\n'
      'DTSTART:20260921T120000Z\nSUMMARY:直播\nEND:VEVENT\nEND:VCALENDAR\n',
    );
    expect(events.single.title, '直播');
  });

  test('malformed transport data is not a legitimate empty calendar', () {
    for (final body in ['', 'not a calendar at all', 'BEGIN:VEVENT']) {
      expect(() => IcsParser.parse(body), throwsFormatException);
    }
    expect(IcsParser.parse(_calendar('')), isEmpty);
  });
  test('Shanghai named time is independent of the device timezone', () {
    final event = IcsParser.parse(
      _calendar(
        'BEGIN:VEVENT\nUID:shanghai\nDTSTART;TZID=Asia/Shanghai:20260921T200000\nEND:VEVENT',
      ),
    ).single;
    expect(event.start, DateTime.utc(2026, 9, 21, 12));
  });

  test('Los Angeles follows seasonal DST rather than a fixed offset', () {
    expect(
      IcsParser.parseDateTime('20260121T120000', {
        'TZID': 'America/Los_Angeles',
      })!.value,
      DateTime.utc(2026, 1, 21, 20),
    );
    expect(
      IcsParser.parseDateTime('20260721T120000', {
        'TZID': 'America/Los_Angeles',
      })!.value,
      DateTime.utc(2026, 7, 21, 19),
    );
  });

  test('floating schedule values use Shanghai, not host local time', () {
    expect(
      IcsParser.parseDateTime('20260921T200000', {})!.value,
      DateTime.utc(2026, 9, 21, 12),
    );
  });

  test('unknown zones and nonexistent DST wall times fail explicitly', () {
    expect(
      () =>
          IcsParser.parseDateTime('20260921T200000', {'TZID': 'Unknown/Zone'}),
      throwsFormatException,
    );
    expect(
      () => IcsParser.parseDateTime('20260308T023000', {
        'TZID': 'America/Los_Angeles',
      }),
      throwsFormatException,
    );
    expect(IcsParser.parseDateTime('20260230', {'VALUE': 'DATE'}), isNull);
  });

  test('the highest sequence wins even when old revisions arrive last', () {
    String event(int sequence, String time, String status) =>
        'BEGIN:VEVENT\nUID:revision\nSEQUENCE:$sequence\nDTSTART:$time\nSTATUS:$status\nEND:VEVENT';
    final events = IcsParser.parse(
      _calendar(
        [
          event(3, '20260921T140000Z', 'CANCELLED'),
          event(1, '20260921T120000Z', 'CONFIRMED'),
        ].join('\n'),
      ),
    );
    expect(events, hasLength(1));
    expect(events.single.sequence, 3);
    expect(events.single.isCancelled, isTrue);
  });

  test('recurrence identity normalizes equivalent named-zone and UTC stamps', () {
    final events = IcsParser.parse(
      _calendar(
        'BEGIN:VEVENT\nUID:series\nRECURRENCE-ID;TZID=Asia/Shanghai:20260921T200000\n'
        'DTSTART:20260921T140000Z\nEND:VEVENT',
      ),
    );
    expect(events.single.identity, '["series","20260921T120000Z"]');
  });

  test('alarm properties cannot overwrite the event fields', () {
    final event = IcsParser.parse(
      _calendar(
        'BEGIN:VEVENT\nUID:a\nDTSTART:20260921T120000Z\nSUMMARY:直播\n'
        'BEGIN:VALARM\nSUMMARY:提醒\nEND:VALARM\nEND:VEVENT',
      ),
    ).single;
    expect(event.title, '直播');
  });

  test('a slash in a UID cannot collide with another occurrence key', () {
    final events = IcsParser.parse(
      _calendar(
        'BEGIN:VEVENT\nUID:series/20260921T120000Z\nDTSTART:20260921T120000Z\nEND:VEVENT\n'
        'BEGIN:VEVENT\nUID:series\nRECURRENCE-ID:20260921T120000Z\nDTSTART:20260921T120000Z\nEND:VEVENT',
      ),
    );
    expect(events, hasLength(2));
    expect(events.map((event) => event.identity).toSet(), hasLength(2));
  });

  test('unsupported recurrence cannot masquerade as a complete schedule', () {
    expect(
      () => IcsParser.parse(
        _calendar(
          'BEGIN:VEVENT\nUID:a\nDTSTART:20260921T120000Z\nRRULE:FREQ=DAILY\nEND:VEVENT',
        ),
      ),
      throwsFormatException,
    );
  });
}
