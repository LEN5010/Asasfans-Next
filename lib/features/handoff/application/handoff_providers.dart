import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/storage/storage_providers.dart';
import '../data/sqlite_return_store.dart';
import 'handoff_coordinator.dart';

final returnStoreProvider = Provider<ReturnStore>(
  (ref) => SqliteReturnStore(ref.watch(localDatabaseProvider)),
);

/// One coordinator for the whole app: the busy flag that stops a double tap
/// only means anything if every entry point shares it.
final handoffCoordinatorProvider = Provider<HandoffCoordinator>((ref) {
  final coordinator = HandoffCoordinator(
    ref.watch(externalLinkServiceProvider),
    ref.watch(returnStoreProvider),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
