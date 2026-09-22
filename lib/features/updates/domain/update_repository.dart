import '../../library/domain/library_page.dart';
import 'update_event.dart';

/// Which slice of the inbox a query wants.
enum UpdateFilter {
  /// Everything that has not been archived, read or not.
  inbox,

  /// Unread and not archived.
  unread,

  /// Archived only.
  archived,
}

/// Unread counts the inbox badge and the Today module read.
class UpdateCounts {
  const UpdateCounts({this.unread = 0, this.inbox = 0});
  final int unread;
  final int inbox;
}

/// Owns stored updates, their cursors and their read/archive state.
///
/// Read and archive state is a personal asset: it survives the source no longer
/// returning the item, and clearing a cache must never reset it.
abstract interface class UpdateRepository {
  /// Commits one harvest atomically.
  ///
  /// Events and the cursors that produced them move together: a partial commit
  /// would either lose events the cursor claims were consumed, or replay events
  /// the user already dismissed. Re-committing the same event id is a no-op on
  /// its user state — a second poll must not resurrect a read item.
  Future<void> commit(UpdateHarvest harvest);

  /// Cursors by source key, for the next collection pass.
  Future<Map<String, UpdateCursor>> cursors();

  Future<LibraryPage<UpdateEvent>> page({
    required UpdateFilter filter,
    LibraryCursor? cursor,
    int limit,
  });

  Future<UpdateCounts> counts();

  Future<void> markRead(Iterable<String> ids, {required bool read});
  Future<void> archive(Iterable<String> ids, {required bool archived});

  /// Marks everything currently in the inbox read. Archived entries are left
  /// alone: the user already dealt with them.
  Future<void> markAllRead();

  Stream<int> get changes;
  Future<void> close();
}
