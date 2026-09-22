import '../../../core/network/api_failure.dart';
import '../../calendar/domain/calendar_event.dart';
import '../../creator/domain/creator_repository.dart';
import '../../library/domain/library_models.dart';
import '../domain/update_event.dart';

/// Turns current source state into inbox events.
///
/// It is a pure-ish collection pass: it reads sources and compares them with
/// the stored cursors, and it never writes. Committing is the repository's job,
/// so a failed write cannot leave a cursor ahead of its events.
class UpdateCollector {
  UpdateCollector(this._creators, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final CreatorRepository _creators;
  final DateTime Function() _clock;

  /// How many of the newest videos per creator one pass may turn into events.
  ///
  /// A creator who posted 40 times since the last check produces a bounded
  /// burst, not 40 inbox rows. The cursor still advances past the whole page,
  /// so the skipped middle is not re-offered later — the user gets the newest
  /// ones, which is what an update feed is for.
  static const perCreatorLimit = 5;

  static String creatorSourceKey(String mid) => 'creator:$mid';
  static String calendarSourceKey(Uri source) => 'calendar:$source';

  /// Reads one page per creator. One creator's failure is recorded and the
  /// others still produce events.
  Future<UpdateHarvest> collectSubscriptions(
    List<LocalSubscription> creators,
    Map<String, UpdateCursor> cursors, {
    RequestCancellation? cancellation,
  }) async {
    final events = <UpdateEvent>[];
    final advanced = <String, UpdateCursor>{};
    final failed = <String>{};
    final baselined = <String>{};
    final now = _clock().toUtc();
    for (final creator in creators) {
      if (cancellation?.isCancelled == true) {
        throw const ApiFailure(ApiFailureKind.cancelled);
      }
      final key = creatorSourceKey(creator.mid);
      final cursor = cursors[key];
      CreatorArchivePage page;
      try {
        page = await _creators.archives(
          CreatorArchiveQuery(mid: creator.mid),
          page: 1,
          cancellation: cancellation,
        );
      } catch (error) {
        if (error is ApiFailure && error.kind == ApiFailureKind.cancelled) {
          rethrow;
        }
        failed.add(key);
        continue;
      }
      // Only items the source dated can be ordered or compared with a cursor.
      final dated = [
        for (final item in page.items)
          if (item.publishedAt != null) item,
      ]..sort((a, b) => b.publishedAt!.compareTo(a.publishedAt!));
      if (cursor == null) {
        // First sight of this creator. Record where "new" starts and say
        // nothing: the user subscribed to hear about the next upload, not to be
        // handed the back catalogue.
        baselined.add(key);
        advanced[key] = UpdateCursor(
          sourceKey: key,
          baselineAt: now,
          lastOccurredAt: dated.isEmpty ? null : dated.first.publishedAt,
          lastId: dated.isEmpty
              ? null
              : UpdateIds.subscriptionVideo(dated.first.identity),
        );
        continue;
      }
      var newest = cursor.lastOccurredAt;
      var newestId = cursor.lastId;
      var produced = 0;
      for (final item in dated) {
        final id = UpdateIds.subscriptionVideo(item.identity);
        final at = item.publishedAt!;
        if (!cursor.accepts(at, id)) continue;
        if (newest == null ||
            at.isAfter(newest) ||
            (at.isAtSameMomentAs(newest) &&
                (newestId == null || id.compareTo(newestId) > 0))) {
          newest = at;
          newestId = id;
        }
        if (produced >= perCreatorLimit) continue;
        produced++;
        events.add(
          UpdateEvent(
            id: id,
            kind: UpdateKind.subscriptionVideo,
            title: item.title,
            subtitle: creator.name,
            occurredAt: at,
            observedAt: now,
            content: item.identity,
            creator: creator,
          ),
        );
      }
      advanced[key] = UpdateCursor(
        sourceKey: key,
        baselineAt: cursor.baselineAt,
        lastOccurredAt: newest,
        lastId: newestId,
      );
    }
    return UpdateHarvest(
      events: events,
      cursors: advanced,
      failedSources: failed,
      baselinedSources: baselined,
    );
  }

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
