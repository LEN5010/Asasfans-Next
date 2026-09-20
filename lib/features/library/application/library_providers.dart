import '../domain/library_repository.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/content_identity.dart';
import '../../../core/storage/storage_providers.dart';
import '../../../core/time/shanghai_date_provider.dart';
import '../data/sqlite_library_repository.dart';
import '../domain/library_models.dart';
import '../domain/library_page.dart';
import 'library_pager.dart';

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  final repository = SqliteLibraryRepository(
    ref.watch(localDatabaseProvider),
    clock: ref.watch(currentTimeProvider),
  );
  ref.onDispose(() => unawaited(repository.close()));
  return repository;
});
final _changesProvider = StreamProvider<int>(
  (ref) => ref.watch(libraryRepositoryProvider).changes,
);
void _watchChanges(Ref ref) {
  ref.watch(_changesProvider.select((value) => value.valueOrNull ?? 0));
}

final collectionFolderProvider = FutureProvider.autoDispose
    .family<CollectionFolder?, String>((ref, id) {
      _watchChanges(ref);
      return ref.watch(libraryRepositoryProvider).folder(id);
    });
final libraryItemStateProvider = FutureProvider.autoDispose
    .family<LibraryItemState, ContentIdentity>((ref, id) {
      _watchChanges(ref);
      return ref.watch(libraryRepositoryProvider).itemState(id);
    });
final libraryRecordsProvider = StateNotifierProvider.autoDispose
    .family<
      LibraryPager<LibraryRecord>,
      LibraryListState<LibraryRecord>,
      LibraryQuery
    >((ref, query) {
      final repository = ref.watch(libraryRepositoryProvider);
      return LibraryPager(
        (cursor) => repository.recordPage(query, cursor: cursor),
        repository.changes,
      );
    });
final libraryFoldersProvider =
    StateNotifierProvider.autoDispose<
      LibraryPager<CollectionFolder>,
      LibraryListState<CollectionFolder>
    >((ref) {
      final repository = ref.watch(libraryRepositoryProvider);
      return LibraryPager(
        (cursor) => repository.folderPage(cursor: cursor),
        repository.changes,
      );
    });
final localSubscriptionsProvider =
    StateNotifierProvider.autoDispose<
      LibraryPager<LocalSubscription>,
      LibraryListState<LocalSubscription>
    >((ref) {
      final repository = ref.watch(libraryRepositoryProvider);
      return LibraryPager(
        (cursor) => repository.subscriptionPage(cursor: cursor),
        repository.changes,
      );
    });
final calendarFollowsProvider =
    StateNotifierProvider.autoDispose<
      LibraryPager<CalendarFollow>,
      LibraryListState<CalendarFollow>
    >((ref) {
      final repository = ref.watch(libraryRepositoryProvider);
      return LibraryPager(
        (cursor) => repository.calendarFollowPage(cursor: cursor),
        repository.changes,
      );
    });
final isSubscribedProvider = FutureProvider.autoDispose.family<bool, String>((
  ref,
  mid,
) {
  _watchChanges(ref);
  return ref.watch(libraryRepositoryProvider).isSubscribed(mid);
});
final isFollowingCalendarProvider = FutureProvider.autoDispose
    .family<bool, CalendarFollowKey>((ref, key) {
      _watchChanges(ref);
      return ref.watch(libraryRepositoryProvider).isFollowingCalendar(key);
    });
