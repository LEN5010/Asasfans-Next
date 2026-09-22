import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/storage/storage_providers.dart';
import '../data/sqlite_return_store.dart';
import 'handoff_coordinator.dart';
import 'return_entry_controller.dart';

final returnStoreProvider = Provider<ReturnStore>(
  (ref) => SqliteReturnStore(ref.watch(localDatabaseProvider)),
);

/// One coordinator for the whole app: the busy flag that stops a double tap
/// only means anything if every entry point shares it.
final handoffCoordinatorProvider = Provider<HandoffCoordinator>((ref) {
  final coordinator = HandoffCoordinator(
    ref.watch(externalLinkServiceProvider),
    ref.watch(returnStoreProvider),
    entry: ref.watch(returnEntryControllerProvider),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

/// One controller too, for the same reason: two would each think they owned
/// the single overlay the platform actually has.
///
/// No `onDispose` here: ChangeNotifierProvider disposes the notifier it holds,
/// and registering it again would dispose the same controller twice.
final returnEntryControllerProvider =
    ChangeNotifierProvider<ReturnEntryController>(
      (ref) => ReturnEntryController(ref.watch(returnEntryServiceProvider)),
    );
