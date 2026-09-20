import 'package:asasfans_next/core/time/calendar_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    'Shanghai grouping uses the source instant, all-day dates do not shift',
    () {
      expect(
        CalendarTime.dayOf(DateTime.utc(2026, 9, 21, 18)),
        DateTime.utc(2026, 9, 22),
      );
      expect(
        CalendarTime.dayOf(DateTime.utc(2026, 9, 21), allDay: true),
        DateTime.utc(2026, 9, 21),
      );
    },
  );
}
