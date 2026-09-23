import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_providers.dart';
import '../../../core/time/shanghai_date_provider.dart';
import '../../library/application/library_providers.dart';
import '../../library/application/library_pager.dart';
import '../data/sqlite_update_repository.dart';
import '../domain/update_event.dart';
import '../domain/update_repository.dart';
import 'update_collector.dart';
import 'update_controller.dart';

final updateRepositoryProvider = Provider<UpdateRepository>((ref) {
  final repository = SqliteUpdateRepository(ref.watch(localDatabaseProvider));
  ref.onDispose(() => unawaited(repository.close()));
  return repository;
});

final updateCollectorProvider = Provider<UpdateCollector>(
  (ref) => UpdateCollector(clock: ref.watch(currentTimeProvider)),
);

/// No `onDispose`: ChangeNotifierProvider already disposes the notifier it
/// holds, so registering it again would dispose the same controller twice.
final updateControllerProvider = ChangeNotifierProvider<UpdateController>(
  (ref) => UpdateController(
    ref.watch(updateCollectorProvider),
    ref.watch(updateRepositoryProvider),
    ref.watch(libraryRepositoryProvider),
  ),
);

final _changesProvider = StreamProvider<int>(
  (ref) => ref.watch(updateRepositoryProvider).changes,
);

/// The inbox badge. Zero and "not loaded yet" are different: a badge is not
/// rendered until a real count arrives, so the app never claims an empty inbox
/// it has not read.
final unreadUpdateCountProvider = FutureProvider<UpdateCounts>((ref) {
  ref.watch(_changesProvider.select((value) => value.valueOrNull ?? 0));
  return ref.watch(updateRepositoryProvider).counts();
});

final updateListProvider = StateNotifierProvider.autoDispose
    .family<
      LibraryPager<UpdateEvent>,
      LibraryListState<UpdateEvent>,
      UpdateFilter
    >((ref, filter) {
      final repository = ref.watch(updateRepositoryProvider);
      return LibraryPager(
        (cursor) => repository.page(filter: filter, cursor: cursor),
        repository.changes,
      );
    });

/// The newest few unread entries, for the Today module. It deliberately does
/// not page: Today shows what is waiting, the inbox shows everything.
final recentUpdatesProvider = FutureProvider.autoDispose<List<UpdateEvent>>((
  ref,
) async {
  ref.watch(_changesProvider.select((value) => value.valueOrNull ?? 0));
  final page = await ref
      .watch(updateRepositoryProvider)
      .page(filter: UpdateFilter.inbox, limit: 5);
  return page.items;
});
