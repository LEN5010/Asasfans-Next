import 'dart:io';

import 'package:asasfans_next/core/storage/local_database.dart';
import 'package:asasfans_next/core/storage/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Windows resolves its storage path in a worker and opens the personal DB',
    () async {
      final container = ProviderContainer();
      final database = container.read(localDatabaseProvider);
      addTearDown(() async {
        await database.close();
        container.dispose();
      });

      final results = await database.batch(const [
        SqlStatement('PRAGMA database_list', [], true),
        SqlStatement('PRAGMA user_version', [], true),
      ]);
      final file = results.first.single['file']! as String;
      expect(file, endsWith(path.join('asasfans_flutter', 'personal.sqlite3')));
      expect(results.last.single['user_version'], SqliteExecutor.schemaVersion);
    },
    skip: !Platform.isWindows,
  );
}
