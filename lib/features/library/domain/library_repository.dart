import '../../../core/domain/content_identity.dart';
import '../../calendar/domain/calendar_event.dart';
import 'library_models.dart';
import 'library_page.dart';

/// New local assets are independent of Bilibili follows and site accounts.
/// No Android legacy-import dependency or compatibility bridge is involved.
abstract interface class LibraryRepository {
  Stream<int> get changes;
  Stream<int> get subscriptionChanges;

  /// Notify readers only after a separate backup transaction has committed.
  void notifyExternalCommit();
  Future<LibraryPage<CollectionFolder>> folderPage({
    LibraryCursor? cursor,
    int limit = 40,
  });
  Future<LibraryPage<LibraryRecord>> recordPage(
    LibraryQuery query, {
    LibraryCursor? cursor,
    int limit = 40,
  });
  Future<LibraryPage<LocalSubscription>> subscriptionPage({
    LibraryCursor? cursor,
    int limit = 40,
  });
  Future<LibraryPage<CalendarFollow>> calendarFollowPage({
    LibraryCursor? cursor,
    int limit = 40,
  });
  Future<bool> isSubscribed(String mid);
  Future<bool> isFollowingCalendar(CalendarFollowKey key);
  Future<List<CollectionFolder>> folders();
  Future<CollectionFolder?> folder(String id);
  Future<String> createFolder(String name);
  Future<void> renameFolder(String id, String name);
  Future<void> deleteFolder(String id);
  Future<LibraryItemState> itemState(ContentIdentity identity);
  Future<void> setCollected(
    ContentSnapshot item,
    String folderId,
    bool collected,
  );
  Future<List<LibraryRecord>> collection(String folderId);
  Future<void> setLater(ContentSnapshot item, bool saved);
  Future<void> setLaterDone(ContentIdentity identity, bool done);
  Future<List<LibraryRecord>> later();
  Future<void> recordHistory(ContentSnapshot item, HistoryAction action);
  Future<List<LibraryRecord>> history({HistoryAction? action});
  Future<void> removeHistory(ContentIdentity identity, HistoryAction action);
  Future<void> clearHistory({HistoryAction? action});

  /// Progress and bookmarks are keyed by source part id. Saving either keeps the
  /// content snapshot alive, so a resume entry never loses its title.
  Future<LibraryPage<PlaybackRecord>> progressPage({
    bool unfinishedOnly = true,
    LibraryCursor? cursor,
    int limit = 40,
  });
  Future<LibraryPage<BookmarkRecord>> bookmarkPage({
    LibraryCursor? cursor,
    int limit = 40,
  });

  /// Null when the part has no stored position. Absence is not position zero.
  Future<PlaybackProgress?> progress(PlaybackPart part);

  /// Every stored part of one item, for a part list that shows which parts were
  /// already watched.
  Future<Map<String, PlaybackProgress>> contentProgress(
    ContentIdentity identity,
  );

  /// Writes are frequent during playback; callers coalesce and rate-limit rather
  /// than calling this on every frame. A position at or past the completion tail
  /// marks the part finished.
  Future<void> saveProgress(
    ContentSnapshot item,
    String partId,
    Duration position, {
    Duration duration = Duration.zero,
    bool? completed,
  });
  Future<void> removeProgress(PlaybackPart part);

  /// Clears stored positions without touching bookmarks, history or saved items.
  Future<void> clearProgress();

  /// Ordered by time within the part, so a player can step through them.
  Future<List<PlaybackBookmark>> bookmarks(PlaybackPart part);
  Future<String> addBookmark(
    ContentSnapshot item,
    String partId,
    Duration start, {
    Duration? end,
    String title = '',
    String note = '',
  });
  Future<void> updateBookmark(
    String id, {
    String? title,
    String? note,
    Duration? start,
    Duration? end,
    bool clearEnd = false,
  });
  Future<void> removeBookmark(String id);

  Future<List<LocalSubscription>> subscriptions();
  Future<void> subscribe(LocalSubscription creator);
  Future<void> unsubscribe(String mid);
  Future<List<CalendarFollow>> calendarFollows();
  Future<void> followCalendar(CalendarFollowKey key, CalendarEvent event);
  Future<void> unfollowCalendar(CalendarFollowKey key);
  Future<void> synchronizeCalendar(
    Uri source,
    List<CalendarEvent> events,
    DateTime observedAt,
  );
  Future<void> close();
}
