import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_providers.dart';
import '../../../core/time/shanghai_date_provider.dart';
import '../../library/application/library_providers.dart';
import '../../preferences/application/preferences_controller.dart';
import '../data/backup_files.dart';
import '../data/sqlite_backup_repository.dart';
import '../domain/personal_backup.dart';

final backupFilesProvider = Provider<BackupFiles>(
  (ref) => PlatformBackupFiles(),
);
final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  final library = ref.watch(libraryRepositoryProvider);
  final preferences = ref.watch(preferencesControllerProvider.notifier);
  return SqliteBackupRepository(
    ref.watch(localDatabaseProvider),
    clock: ref.watch(currentTimeProvider),
    onCommitted: () {
      library.notifyExternalCommit();
      unawaited(preferences.reloadAfterExternalWrite());
    },
  );
});
