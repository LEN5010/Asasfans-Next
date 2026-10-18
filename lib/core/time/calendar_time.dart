import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;

/// Source timestamps keep their zone; presentation follows the device zone.
abstract final class CalendarTime {
  static const scheduleZone = 'Asia/Shanghai';
  static bool _initialized = false;

  static tz.Location location(String name) {
    if (!_initialized) {
      data.initializeTimeZones();
      _initialized = true;
    }
    try {
      return tz.getLocation(name);
    } on Exception {
      throw FormatException('Unsupported calendar timezone: $name');
    }
  }

  static DateTime wallTimeToUtc(DateTime fields, String zone) {
    final value = tz.TZDateTime(
      location(zone),
      fields.year,
      fields.month,
      fields.day,
      fields.hour,
      fields.minute,
      fields.second,
    );
    // A spring-forward gap must not silently move a programme to another time.
    if (value.year != fields.year ||
        value.month != fields.month ||
        value.day != fields.day ||
        value.hour != fields.hour ||
        value.minute != fields.minute ||
        value.second != fields.second) {
      throw const FormatException('Calendar time falls in a timezone gap');
    }
    // Return a core UTC value: timezone Location identity is isolate-local.
    return DateTime.fromMicrosecondsSinceEpoch(
      value.microsecondsSinceEpoch,
      isUtc: true,
    );
  }

  /// UTC is only a carrier for pure Y/M/D values here, not an instant.
  static DateTime dayOf(DateTime value, {bool allDay = false}) {
    final day = allDay ? value : value.toLocal();
    return DateTime.utc(day.year, day.month, day.day);
  }

  static DateTime selectDayInMonth(DateTime month, DateTime preferred) {
    final last = DateTime.utc(month.year, month.month + 1, 0).day;
    return DateTime.utc(
      month.year,
      month.month,
      preferred.day > last ? last : preferred.day,
    );
  }
}
