// Host-side measurement for T13: what one LocalDatabase.batch costs, split
// into the per-batch lifecycle (isolate spawn + open + initialize + dispose)
// and the SQL itself. Run from the repository root:
//   dart run reports/optimization/run-02/sql_lifecycle_bench.dart
// Host numbers are not device numbers; the ratio is what informs T34.
import 'dart:io';
import 'dart:isolate';

import 'package:asasfans_next/core/storage/local_database.dart';
import 'package:sqlite3/sqlite3.dart';

const _read = SqlStatement('SELECT key, value FROM preferences', [], true);
const _write = SqlStatement(
  'INSERT INTO preferences(key, value) VALUES (?, ?) '
  'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
  ['bench', 'x'],
);

Future<List<double>> sample(int n, Future<void> Function() body) async {
  final times = <double>[];
  for (var i = 0; i < n; i++) {
    final watch = Stopwatch()..start();
    await body();
    times.add(watch.elapsedMicroseconds / 1000);
  }
  times.sort();
  return times;
}

String describe(String name, List<double> t) {
  double q(double p) => t[((t.length - 1) * p).round()];
  return '${name.padRight(40)} n=${t.length}  p50=${q(.5).toStringAsFixed(2)}ms'
      '  p90=${q(.9).toStringAsFixed(2)}ms  max=${t.last.toStringAsFixed(2)}ms';
}

Future<void> main() async {
  final dir = await Directory.systemTemp.createTemp('asasfans-sql-bench');
  final path = '${dir.path}/app.sqlite';
  final db = IsolateLocalDatabase(() async => path);
  await db.batch([_write], write: true); // create schema once
  const n = 200;
  final lines = <String>[
    'host: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    'cpus: ${Platform.numberOfProcessors}',
    'dart: ${Platform.version.split(' ').first}',
    '',
    describe('batch(read) via IsolateLocalDatabase', await sample(n, () => db.batch([_read]))),
    describe('batch(write+read) via IsolateLocalDatabase', await sample(n, () => db.batch([_write, _read], write: true))),
    describe('Isolate.run(no-op)', await sample(n, () => Isolate.run(() => 0))),
    describe('open+initialize+read+dispose (same isolate)', await sample(n, () async => SqliteExecutor.openBatch(path, [_read]))),
  ];
  final open = sqlite3.open(path);
  SqliteExecutor.initialize(open);
  lines.add(describe('read on an already-open connection', await sample(n, () async => SqliteExecutor.execute(open, [_read]))));
  lines.add(describe('write+read on an already-open connection', await sample(n, () async => SqliteExecutor.execute(open, [_write, _read], write: true))));
  open.dispose();
  await db.close();
  await dir.delete(recursive: true);
  print(lines.join('\n'));
}
