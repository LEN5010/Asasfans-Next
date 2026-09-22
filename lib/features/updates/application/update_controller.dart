import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/domain/request_cancellation.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/storage/storage_failure.dart';
import '../../calendar/domain/calendar_event.dart';
import '../../library/domain/library_repository.dart';
import '../domain/update_repository.dart';
import 'update_collector.dart';

/// Runs collection passes and owns the state a refresh button needs.
///
/// Nothing here delivers a system notification. A pass that finds updates has
/// filled the in-app inbox and no more than that; whether the device ever tells
/// the user is a separate, later capability.
class UpdateController extends ChangeNotifier {
  UpdateController(this._collector, this._updates, this._library);

  final UpdateCollector _collector;
  final UpdateRepository _updates;
  final LibraryRepository _library;

  RequestCancellation? _request;
  bool _closed = false;
  int _generation = 0;

  bool running = false;

  /// Sources that could not be read on the last pass. Their absence from the
  /// inbox is a gap, not a quiet "nothing new", and the UI says so.
  int failedSources = 0;

  /// True when the last pass only established baselines. The first run after
  /// subscribing deliberately produces nothing.
  bool baselineOnly = false;

  DateTime? lastRunAt;
  ApiFailure? failure;
  StorageFailure? storageFailure;

  /// Reads every subscribed creator once and commits whatever it found.
  ///
  /// The calendar half is driven separately by [recordCalendarSnapshot],
  /// because a change can only be seen while the previously observed revision
  /// is still stored — once the calendar sync has written the new snapshot, the
  /// comparison point is gone.
  Future<void> run() async {
    if (_closed || running) return;
    final generation = ++_generation;
    final cancellation = _request = RequestCancellation();
    running = true;
    failure = null;
    storageFailure = null;
    notifyListeners();
    try {
      final creators = await _library.subscriptions();
      if (!_active(generation)) return;
      final cursors = await _updates.cursors();
      if (!_active(generation)) return;
      final harvest = await _collector.collectSubscriptions(
        creators,
        cursors,
        cancellation: cancellation,
      );
      if (!_active(generation)) return;
      await _updates.commit(harvest);
      if (!_active(generation)) return;
      failedSources = harvest.failedSources.length;
      baselineOnly =
          harvest.events.isEmpty && harvest.baselinedSources.isNotEmpty;
      lastRunAt = DateTime.now().toUtc();
    } catch (error) {
      if (!_active(generation)) return;
      if (error is StorageFailure) {
        storageFailure = error;
      } else if (error is! ApiFailure ||
          error.kind != ApiFailureKind.cancelled) {
        failure = error is ApiFailure
            ? error
            : const ApiFailure(ApiFailureKind.invalidResponse);
      }
    } finally {
      if (_active(generation)) {
        running = false;
        notifyListeners();
      }
    }
  }

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

  bool _active(int generation) => !_closed && generation == _generation;

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    _generation++;
    _request?.cancel();
    super.dispose();
  }
}
