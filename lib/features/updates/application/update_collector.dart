import '../../calendar/domain/calendar_event.dart';
import '../../library/domain/library_models.dart';
import '../domain/update_event.dart';

/// Turns current source state into inbox events.
///
/// It compares a source with what was stored and never writes. Committing is
/// the repository's job, so a failed write cannot leave a cursor ahead of its
/// events.
///
/// Subscribed creators are no longer polled: videos are indexed by the
/// asasfans backend and watched on Bilibili. Subscription entries already in
/// the inbox stay readable, but nothing adds new ones.
class UpdateCollector {
  UpdateCollector({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  static String calendarSourceKey(Uri source) => 'calendar:$source';

  /// Compares followed occurrences with the calendar snapshot the app just read.
  ///
  /// The stored follow holds the last observed revision, so a change is only
  /// reported when the source's own `SEQUENCE` moved forward. Absence from the
  /// snapshot is not cancellation — a source that returned a shorter window
  /// must not be read as the event having been called off.
  ///
  /// Unlike a creator feed, this source needs no time cursor: the follow row
  /// itself records the revision it was taken at, and the event id carries the
  /// new revision, so a repeat pass collides on the id instead of duplicating.
  /// A time cursor would actively be wrong here, because an occurrence moved
  /// *earlier* is a real change whose start time went backwards.
  UpdateHarvest collectSchedule({
    required Uri source,
    required List<CalendarFollow> follows,
    required List<CalendarEvent> events,
  }) {
    final key = calendarSourceKey(source);
    final now = _clock().toUtc();
    final produced = <UpdateEvent>[];
    final byKey = {
      for (final event in events)
        CalendarFollowKey(
          source: source,
          uid: event.uid,
          recurrenceId: event.recurrenceId,
        ): event,
    };
    for (final follow in follows) {
      if (follow.key.source != source) continue;
      final current = byKey[follow.key];
      if (current == null || current.sequence <= follow.event.sequence) {
        continue;
      }
      final change = current.isCancelled && !follow.event.isCancelled
          ? ScheduleChange.cancelled
          : current.start != follow.event.start ||
                current.end != follow.event.end
          ? ScheduleChange.rescheduled
          : null;
      if (change == null) continue;
      produced.add(
        UpdateEvent(
          id: UpdateIds.scheduleChange(follow.key, current.sequence),
          kind: UpdateKind.scheduleChange,
          title: current.title,
          subtitle: change == ScheduleChange.cancelled ? '已取消' : '时间有变动',
          // Ordered by when the occurrence itself is, so a change to a far-off
          // event does not claim to have just happened.
          occurredAt: current.start,
          observedAt: now,
          followKey: follow.key,
          scheduleChange: change,
        ),
      );
    }
    return UpdateHarvest(
      events: produced,
      // The cursor row exists only to record that this calendar has been read
      // at all; the per-occurrence comparison lives in the follow rows.
      cursors: {key: UpdateCursor(sourceKey: key, baselineAt: now)},
      failedSources: const {},
    );
  }
}
