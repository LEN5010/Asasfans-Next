// Host-side check for T35's activation condition: how long IcsParser.parse
// takes on the UI isolate for calendars far larger than the real feed.
//   dart run reports/optimization/run-02/ics_parse_bench.dart
import 'dart:io';

import 'package:asasfans_next/features/calendar/data/ics_parser.dart';

String calendar(int events) {
  final out = StringBuffer('BEGIN:VCALENDAR\r\nVERSION:2.0\r\n');
  for (var i = 0; i < events; i++) {
    final day = 1 + i % 28;
    final month = 1 + (i ~/ 28) % 12;
    String two(int n) => n.toString().padLeft(2, '0');
    out
      ..write('BEGIN:VEVENT\r\n')
      ..write('UID:event-$i@bench\r\n')
      ..write(
        'DTSTART;TZID=Asia/Shanghai:2026${two(month)}${two(day)}T190000\r\n',
      )
      ..write(
        'DTEND;TZID=Asia/Shanghai:2026${two(month)}${two(day)}T210000\r\n',
      )
      ..write('SUMMARY:嘉然 直播 第$i场 \\, 杂谈与歌回\r\n')
      ..write('DESCRIPTION:一段较长的说明文字，用来接近真实日程的描述长度。第$i条。\r\n')
      ..write('END:VEVENT\r\n');
  }
  return (out..write('END:VCALENDAR\r\n')).toString();
}

void main() {
  final lines = <String>[
    'host: ${Platform.operatingSystem}, dart ${Platform.version.split(' ').first}',
  ];
  for (final n in [200, 1000, 5000]) {
    final text = calendar(n);
    IcsParser.parse(text); // warm up
    final times = <double>[];
    for (var i = 0; i < 20; i++) {
      final watch = Stopwatch()..start();
      final events = IcsParser.parse(text);
      times.add(watch.elapsedMicroseconds / 1000);
      if (events.isEmpty) throw StateError('parser returned nothing');
    }
    times.sort();
    lines.add(
      '$n events (${(text.length / 1024).toStringAsFixed(0)} KiB): '
      'p50 ${times[10].toStringAsFixed(2)} ms, max ${times.last.toStringAsFixed(2)} ms',
    );
  }
  stdout.writeln(lines.join('\n'));
}
