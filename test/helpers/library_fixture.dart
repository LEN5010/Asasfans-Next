import 'dart:async';

import 'package:asasfans_next/core/storage/storage_providers.dart';
import 'package:asasfans_next/features/library/application/library_providers.dart';
import 'package:asasfans_next/features/library/data/sqlite_library_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sqlite_fixture.dart';
import 'account_fixture.dart';

/// Personal features share one disposable DB, never the application directory.
List<Override> offlineLibrary() => [
  offlineAccount(),
  localDatabaseProvider.overrideWith((ref) {
    final database = MemoryLocalDatabase();
    ref.onDispose(() => unawaited(database.close()));
    return database;
  }),
  libraryRepositoryProvider.overrideWith((ref) {
    final repository = SqliteLibraryRepository(
      ref.watch(localDatabaseProvider),
      backgroundDecoding: false,
      clock: () => DateTime.utc(2026, 9, 21, 4),
    );
    ref.onDispose(() => unawaited(repository.close()));
    return repository;
  }),
];
