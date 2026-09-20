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

  test('a UTC stamp stays UTC and a floating time stays local', () {
    final utc = IcsParser.parseDateTime('20260921T120000Z', const {});
    expect(utc!.value.isUtc, isTrue);
    expect(utc.value, DateTime.utc(2026, 9, 21, 12));

    final floating = IcsParser.parseDateTime('20260921T120000', const {
      'TZID': 'Asia/Shanghai',
    });
    expect(floating!.value.isUtc, isFalse);
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
    expect(events.first.identity, 'series');
    expect(events.last.identity, 'series/20260928T120000Z');
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

  test('an event without a start is skipped rather than invented', () {
    final events = IcsParser.parse(
      _calendar('BEGIN:VEVENT\r\nUID:1\r\nSUMMARY:无开始时间\r\nEND:VEVENT'),
    );
    expect(events, isEmpty);
  });

  test('bare LF line endings parse the same as CRLF', () {
    final events = IcsParser.parse(
      'BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:1\n'
      'DTSTART:20260921T120000Z\nSUMMARY:直播\nEND:VEVENT\nEND:VCALENDAR\n',
    );
    expect(events.single.title, '直播');
  });

  test('an empty or malformed calendar yields no events, not an exception', () {
    expect(IcsParser.parse(''), isEmpty);
    expect(IcsParser.parse('not a calendar at all'), isEmpty);
    expect(IcsParser.parse('BEGIN:VEVENT'), isEmpty);
  });
}
