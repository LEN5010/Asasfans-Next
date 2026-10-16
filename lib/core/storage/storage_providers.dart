import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_windows/path_provider_windows.dart';

import 'local_database.dart';

final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  final database = IsolateLocalDatabase(resolvePersonalDatabasePath);
  ref.onDispose(() => unawaited(database.close()));
  return database;
});

Future<String> resolvePersonalDatabasePath() =>
    Platform.isWindows ? Isolate.run(_windowsDatabasePath) : _databasePath();

Future<String> _windowsDatabasePath() {
  // Windows path_provider reads the executable's version resource and calls
  // synchronous shell APIs. Keep those calls off the UI isolate.
  PathProviderWindows.registerWith();
  return _databasePath();
}

Future<String> _databasePath() async {
  final support = await getApplicationSupportDirectory();
  final directory = Directory(path.join(support.path, 'asasfans_flutter'));
  await directory.create(recursive: true);
  return path.join(directory.path, 'personal.sqlite3');
}
