import 'dart:async';

import '../domain/library_models.dart';
import '../domain/library_repository.dart';

/// Coalesces frequent playback positions into bounded writes.
///
/// A player reports a position many times per second; each write is a real
/// transaction, so reports are merged and rate-limited instead of hitting the
/// database per frame. Only the newest position for a part is ever pending —
/// intermediate positions carry no information once a later one arrives.
///
/// The recorder never decides *when* playback is happening. A caller that stops
/// playing must [flush] so the last real position is durable, and must not rely
/// on a timer still being scheduled.
class ProgressRecorder {
  ProgressRecorder(
    this._repository, {
    this.interval = const Duration(seconds: 5),
  });
  final LibraryRepository _repository;

  /// Shortest gap between two writes for the same part.
  final Duration interval;

  final _pending = <PlaybackPart, _PendingProgress>{};
  Timer? _timer;
  Future<void> _tail = Future.value();
  bool _closed = false;

  /// Records a position without writing immediately.
  ///
  /// [completed] forces the finished state; leaving it null lets the repository
  /// infer completion from the duration. A completed report is written promptly
  /// rather than waiting for the interval, because finishing is the state a user
  /// is most likely to close the app on.
  void record(
    ContentSnapshot item,
    String partId,
    Duration position, {
    Duration duration = Duration.zero,
    bool? completed,
  }) {
    if (_closed) return;
    final part = PlaybackPart(identity: item.identity, partId: partId);
    _pending[part] = _PendingProgress(
      item: item,
      partId: partId,
      position: position,
      duration: duration,
      completed: completed,
    );
    if (completed == true) {
      unawaited(flush());
    } else {
      _timer ??= Timer(interval, () {
        _timer = null;
        unawaited(flush());
      });
    }
  }

  /// Writes everything pending and waits for it. Safe to call when empty.
  ///
  /// Writes are serialized on one queue so two flushes cannot interleave and
  /// store an older position after a newer one.
  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    if (_pending.isEmpty) return _tail;
    final batch = List.of(_pending.values);
    _pending.clear();
    _tail = _tail.then((_) async {
      for (final entry in batch) {
        try {
          await _repository.saveProgress(
            entry.item,
            entry.partId,
            entry.position,
            duration: entry.duration,
            completed: entry.completed,
          );
        } catch (_) {
          // A failed position write must not take down playback. The next
          // report re-attempts, and the stored position stays valid.
        }
      }
    });
    return _tail;
  }

  /// Refuses further reports, then flushes what was already recorded. Callers
  /// dispose this with the player so a background timer cannot outlive the
  /// screen.
  ///
  /// Closing first means a late report during the final write is rejected
  /// outright instead of being accepted and then dropped.
  Future<void> close() {
    if (_closed) return _tail;
    _closed = true;
    return flush();
  }
}

class _PendingProgress {
  const _PendingProgress({
    required this.item,
    required this.partId,
    required this.position,
    required this.duration,
    required this.completed,
  });
  final ContentSnapshot item;
  final String partId;
  final Duration position;
  final Duration duration;
  final bool? completed;
}
