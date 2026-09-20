import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'local_database.dart';

final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  final database = IsolateLocalDatabase(() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(path.join(support.path, 'asasfans_flutter'));
    await directory.create(recursive: true);
    return path.join(directory.path, 'personal.sqlite3');
  });
  ref.onDispose(() => unawaited(database.close()));
  return database;
});
