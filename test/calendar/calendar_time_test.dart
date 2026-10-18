import 'dart:isolate';

import 'package:asasfans_next/core/time/calendar_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a source-zone instant stays UTC when returned from a worker', () async {
    final instant = await Isolate.run(
      () => CalendarTime.wallTimeToUtc(
        DateTime.utc(2026, 9, 21, 20),
        CalendarTime.scheduleZone,
      ),
    );
    expect(instant.isUtc, isTrue);
    expect(instant, DateTime.utc(2026, 9, 21, 12));
    expect(
      instant.add(const Duration(hours: 1)),
      DateTime.utc(2026, 9, 21, 13),
    );
  });

  test('moving between months keeps a valid selected day', () {
    expect(
      CalendarTime.selectDayInMonth(
        DateTime.utc(2026, 10),
        DateTime.utc(2026, 9, 21),
      ),
      DateTime.utc(2026, 10, 21),
    );
    expect(
      CalendarTime.selectDayInMonth(
        DateTime.utc(2026, 2),
        DateTime.utc(2026, 1, 31),
      ),
      DateTime.utc(2026, 2, 28),
    );
    expect(
      CalendarTime.selectDayInMonth(
        DateTime.utc(2028, 2),
        DateTime.utc(2028, 1, 31),
      ),
      DateTime.utc(2028, 2, 29),
    );
  });

  test(
    'Local grouping uses the source instant, all-day dates do not shift',
    () {
      expect(
        CalendarTime.dayOf(DateTime(2026, 9, 22, 2).toUtc()),
        DateTime.utc(2026, 9, 22),
      );
      expect(
        CalendarTime.dayOf(DateTime.utc(2026, 9, 21), allDay: true),
        DateTime.utc(2026, 9, 21),
      );
    },
  );
}
