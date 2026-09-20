import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_providers.dart';
import '../../../core/time/shanghai_date_provider.dart';
import '../../library/application/library_providers.dart';
import '../data/sqlite_rules_repository.dart';
import '../domain/rules_repository.dart';
import 'rules_controller.dart';

final rulesRepositoryProvider = Provider<RulesRepository>((ref) {
  final repo = SqliteRulesRepository(
    ref.watch(localDatabaseProvider),
    clock: ref.watch(currentTimeProvider),
  );
  ref.onDispose(() => unawaited(repo.close()));
  return repo;
});
final rulesControllerProvider =
    StateNotifierProvider<RulesController, RulesState>((ref) {
      final controller = RulesController(
        ref.watch(rulesRepositoryProvider),
        ref.watch(libraryRepositoryProvider).subscriptionChanges,
        clock: ref.watch(currentTimeProvider),
      );
      final lifecycle = AppLifecycleListener(
        onResume: () => unawaited(controller.reload()),
      );
      ref.onDispose(lifecycle.dispose);
      return controller;
    });
