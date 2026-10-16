import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'local_database.dart';

final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  final database = IsolateLocalDatabase(
    () => Platform.isWindows
        ? Isolate.run(_windowsDatabasePath)
        : _databasePath(),
  );
  ref.onDispose(() => unawaited(database.close()));
  return database;
});

Future<String> _windowsDatabasePath() {
  // Windows path_provider reads the executable's version resource and calls
  // synchronous shell APIs. Keep those calls off the UI isolate.
  DartPluginRegistrant.ensureInitialized();
  return _databasePath();
}

Future<String> _databasePath() async {
  final support = await getApplicationSupportDirectory();
  final directory = Directory(path.join(support.path, 'asasfans_flutter'));
  await directory.create(recursive: true);
  return path.join(directory.path, 'personal.sqlite3');
}
