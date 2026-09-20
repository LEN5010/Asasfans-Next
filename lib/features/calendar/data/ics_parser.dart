import '../domain/calendar_event.dart';

/// A parsed but not yet interpreted content line.
class IcsLine {
  const IcsLine(this.name, this.params, this.value);
  final String name;
  final Map<String, String> params;
  final String value;
}

/// An ICS date-time that still knows whether it was a pure date.
class IcsDateTime {
  const IcsDateTime(this.value, {required this.isDate, this.tzid});

  /// For a date-only value this is midnight in the calendar's own terms; it
  /// must not be reinterpreted through the device timezone.
  final DateTime value;
  final bool isDate;
  final String? tzid;
}

/// Minimal but correct iCalendar reader for the events this app displays.
///
/// Covers line folding, escaping, TZID and UTC stamps, pure dates, exclusive
/// DTEND, DURATION, STATUS, SEQUENCE and RECURRENCE-ID. Recurrence expansion
/// (RRULE/RDATE/EXDATE) is deliberately out of scope here: the feed in use
/// publishes explicit occurrences, and a half-implemented RRULE engine would
/// silently invent or drop events.
abstract final class IcsParser {
  static List<CalendarEvent> parse(String text) {
    final events = <CalendarEvent>[];
    Map<String, List<IcsLine>>? current;

    for (final line in unfold(text)) {
      if (line == 'BEGIN:VEVENT') {
        current = {};
        continue;
      }
      if (line == 'END:VEVENT') {
        if (current != null) {
          final event = _build(current);
          if (event != null) events.add(event);
        }
        current = null;
        continue;
      }
      if (current == null) continue;
      final parsed = parseLine(line);
      if (parsed == null) continue;
      current.putIfAbsent(parsed.name, () => []).add(parsed);
    }
    return List.unmodifiable(events);
  }

  /// Joins continuation lines, which begin with a single space or tab, and
  /// tolerates both CRLF and bare LF.
  static List<String> unfold(String text) {
    final lines = <String>[];
    for (final raw
        in text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n')) {
      if (raw.isEmpty) continue;
      if ((raw.startsWith(' ') || raw.startsWith('\t')) && lines.isNotEmpty) {
        lines[lines.length - 1] += raw.substring(1);
      } else {
        lines.add(raw);
      }
    }
    return lines;
  }

  /// Splits `NAME;PARAM=value:content`, honouring quoted parameter values so a
  /// colon inside a quoted parameter does not end the name.
  static IcsLine? parseLine(String line) {
    var colon = -1;
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        quoted = !quoted;
      } else if (char == ':' && !quoted) {
        colon = i;
        break;
      }
    }
    if (colon <= 0) return null;

    final head = line.substring(0, colon);
    final value = line.substring(colon + 1);
    final parts = _splitParams(head);
    final name = parts.first.toUpperCase();
    final params = <String, String>{};
    for (final part in parts.skip(1)) {
      final equals = part.indexOf('=');
      if (equals <= 0) continue;
      var raw = part.substring(equals + 1);
      if (raw.length >= 2 && raw.startsWith('"') && raw.endsWith('"')) {
        raw = raw.substring(1, raw.length - 1);
      }
      params[part.substring(0, equals).toUpperCase()] = raw;
    }
    return IcsLine(name, params, value);
  }

  static List<String> _splitParams(String head) {
    final parts = <String>[];
    final buffer = StringBuffer();
    var quoted = false;
    for (var i = 0; i < head.length; i++) {
      final char = head[i];
      if (char == '"') {
        quoted = !quoted;
        buffer.write(char);
      } else if (char == ';' && !quoted) {
        parts.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    parts.add(buffer.toString());
    return parts;
  }

  /// Reverses text escaping. `\n` and `\N` are newlines; a backslash escapes
  /// itself, commas and semicolons.
  static String decodeText(String value) {
    final buffer = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      final char = value[i];
      if (char != r'\' || i + 1 >= value.length) {
        buffer.write(char);
        continue;
      }
      final next = value[++i];
      buffer.write(switch (next) {
        'n' || 'N' => '\n',
        r'\' => r'\',
        ',' => ',',
        ';' => ';',
        _ => next,
      });
    }
    return buffer.toString();
  }

  /// Reads `YYYYMMDD` and `YYYYMMDDTHHMMSS[Z]`.
  ///
  /// A trailing `Z` is UTC. A TZID is recorded but not resolved here, because
  /// this build carries no timezone database; such values are kept as local
  /// wall-clock times together with their zone name.
  static IcsDateTime? parseDateTime(String value, Map<String, String> params) {
    final raw = value.trim();
    final isDate =
        params['VALUE']?.toUpperCase() == 'DATE' ||
        (raw.length == 8 && !raw.contains('T'));
    if (isDate) {
      if (raw.length < 8) return null;
      final date = _digits(raw, 0, 8);
      if (date == null) return null;
      return IcsDateTime(
        DateTime.utc(date ~/ 10000, (date ~/ 100) % 100, date % 100),
        isDate: true,
      );
    }
    if (raw.length < 15 || raw[8] != 'T') return null;
    final date = _digits(raw, 0, 8);
    final time = _digits(raw, 9, 6);
    if (date == null || time == null) return null;
    final utc = raw.endsWith('Z');
    final year = date ~/ 10000;
    final month = (date ~/ 100) % 100;
    final day = date % 100;
    final hour = time ~/ 10000;
    final minute = (time ~/ 100) % 100;
    final second = time % 100;
    return IcsDateTime(
      utc
          ? DateTime.utc(year, month, day, hour, minute, second)
          : DateTime(year, month, day, hour, minute, second),
      isDate: false,
      tzid: params['TZID'],
    );
  }

  static int? _digits(String raw, int start, int length) {
    if (raw.length < start + length) return null;
    return int.tryParse(raw.substring(start, start + length));
  }

  /// Reads an ISO 8601 duration as used by DURATION, e.g. `-P1DT2H30M`.
  static Duration? parseDuration(String value) {
    final match = RegExp(
      r'^([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$',
    ).firstMatch(value.trim());
    if (match == null) return null;
    int part(int index) => int.tryParse(match.group(index) ?? '') ?? 0;
    final duration = Duration(
      days: part(2) * 7 + part(3),
      hours: part(4),
      minutes: part(5),
      seconds: part(6),
    );
    if (duration == Duration.zero && match.group(0) == 'P') return null;
    return match.group(1) == '-' ? -duration : duration;
  }

  static CalendarEvent? _build(Map<String, List<IcsLine>> fields) {
    final startLine = fields['DTSTART']?.firstOrNull;
    if (startLine == null) return null;
    final start = parseDateTime(startLine.value, startLine.params);
    if (start == null) return null;

    final endLine = fields['DTEND']?.firstOrNull;
    var end = endLine == null
        ? null
        : parseDateTime(endLine.value, endLine.params)?.value;
    if (end == null) {
      final duration = parseDuration(
        fields['DURATION']?.firstOrNull?.value ?? '',
      );
      end = duration != null
          ? start.value.add(duration)
          // An all-day event without an end covers exactly its own day.
          : start.value.add(
              start.isDate ? const Duration(days: 1) : const Duration(hours: 1),
            );
    }
    // DTEND is exclusive, so an end at or before the start is not a range.
    if (!end.isAfter(start.value)) {
      end = start.value.add(
        start.isDate ? const Duration(days: 1) : const Duration(hours: 1),
      );
    }

    final uid = _text(fields, 'UID');
    return CalendarEvent(
      uid: uid.isEmpty ? '${startLine.value}|${_text(fields, 'SUMMARY')}' : uid,
      recurrenceId: fields['RECURRENCE-ID']?.firstOrNull?.value,
      sequence: int.tryParse(_text(fields, 'SEQUENCE')) ?? 0,
      title: _text(fields, 'SUMMARY'),
      start: start.value,
      end: end,
      allDay: start.isDate,
      status: switch (_text(fields, 'STATUS').toUpperCase()) {
        'CANCELLED' => EventStatus.cancelled,
        'TENTATIVE' => EventStatus.tentative,
        _ => EventStatus.confirmed,
      },
      description: _text(fields, 'DESCRIPTION'),
      location: _text(fields, 'LOCATION'),
      categories: _list(fields, 'CATEGORIES'),
      sourceUrl: _uri(_text(fields, 'URL')),
    );
  }

  static String _text(Map<String, List<IcsLine>> fields, String name) {
    final line = fields[name]?.firstOrNull;
    return line == null ? '' : decodeText(line.value).trim();
  }

  static List<String> _list(Map<String, List<IcsLine>> fields, String name) {
    final raw = _text(fields, name);
    if (raw.isEmpty) return const [];
    return List.unmodifiable(
      raw
          .split(',')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty),
    );
  }

  static Uri? _uri(String raw) {
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http')
        ? uri
        : null;
  }
}
