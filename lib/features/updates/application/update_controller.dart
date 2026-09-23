import 'package:flutter/foundation.dart';

import '../../../core/storage/storage_failure.dart';
import '../../calendar/domain/calendar_event.dart';
import '../../library/domain/library_repository.dart';
import '../domain/update_repository.dart';
import 'update_collector.dart';

/// Records schedule changes and owns the inbox actions' failure state.
///
/// Nothing here delivers a system notification. A change it records has
/// filled the in-app inbox and no more than that; whether the device ever tells
/// the user is a separate, later capability.
class UpdateController extends ChangeNotifier {
  UpdateController(this._collector, this._updates, this._library);

  final UpdateCollector _collector;
  final UpdateRepository _updates;
  final LibraryRepository _library;

  bool _closed = false;

  StorageFailure? storageFailure;

  /// Compares a freshly read calendar against the followed revisions.
  ///
  /// Call this before the library's own snapshot synchronization, and never
  /// after: the follow rows hold the revision the user last saw, which is the
  /// only thing a change can be measured against.
  ///
  /// A failure here is swallowed. The calendar itself loaded, and refusing to
  /// show it because an inbox write failed would trade a working feature for a
  /// secondary one.
  Future<void> recordCalendarSnapshot(
    Uri source,
    List<CalendarEvent> events,
  ) async {
    if (_closed) return;
    try {
      final follows = await _library.calendarFollows();
      if (_closed || follows.isEmpty) return;
      final harvest = _collector.collectSchedule(
        source: source,
        follows: follows,
        events: events,
      );
      await _updates.commit(harvest);
    } catch (_) {
      // Leaving the follow rows untouched means the next snapshot compares
      // against the same revision and can still report the change.
    }
  }

  Future<void> markRead(Iterable<String> ids, {bool read = true}) =>
      _guard(() => _updates.markRead(ids, read: read));
  Future<void> archive(Iterable<String> ids, {bool archived = true}) =>
      _guard(() => _updates.archive(ids, archived: archived));
  Future<void> markAllRead() => _guard(_updates.markAllRead);

  Future<void> _guard(Future<void> Function() action) async {
    if (_closed) return;
    try {
      await action();
      if (!_closed) storageFailure = null;
    } catch (error) {
      if (_closed) return;
      storageFailure = error is StorageFailure
          ? error
          : const StorageFailure(StorageFailureKind.unavailable);
    }
    if (!_closed) notifyListeners();
  }

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    super.dispose();
  }
}
