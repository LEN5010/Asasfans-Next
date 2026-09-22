import 'dart:convert';

import '../../../core/domain/content_identity.dart';
import '../../calendar/domain/calendar_event.dart';
import '../../library/domain/library_models.dart';

/// Which source produced an update.
///
/// Only sources with a stable identity are listed. A category is not added
/// because a feed could display it: without an id that survives re-reading the
/// source, every poll would invent new events and the inbox would repeat
/// itself. Fanart updates wait for that contract.
enum UpdateKind {
  /// A new video from a locally subscribed creator.
  subscriptionVideo,

  /// A followed calendar event was rescheduled or cancelled.
  scheduleChange,
}

/// What happened to a followed schedule entry.
enum ScheduleChange {
  /// Start or end time moved.
  rescheduled,

  /// The source marked the occurrence cancelled.
  cancelled,
}

/// A durable, replay-safe identifier for one update.
///
/// The id is derived from the source's own identifiers, never from a position,
/// a poll counter or the local clock. Re-reading the same source state must
/// produce the same id, otherwise a second poll would duplicate the inbox.
///
/// For a schedule change, the observed [CalendarEvent.sequence] is part of the
/// id: a later revision of the same occurrence is genuinely a new thing to tell
/// the user about, while re-reading the same revision is not.
abstract final class UpdateIds {
  static String subscriptionVideo(ContentIdentity content) =>
      'sub:${content.storageKey}';

  /// JSON-encoded rather than delimiter-joined: a uid or recurrence id may
  /// contain any character, so a chosen separator could make two different
  /// occurrences collapse onto the same id.
  static String scheduleChange(CalendarFollowKey key, int sequence) =>
      jsonEncode([
        'cal',
        key.source.toString(),
        key.uid,
        key.recurrenceId,
        sequence,
      ]);
}

/// One entry in the in-app inbox.
///
/// It is an application-local record of something the app observed, not a push
/// notification and not proof that the user was told. Delivery through a system
/// channel is a separate concern (A5) and its absence must not stop an update
/// from being stored and read here.
class UpdateEvent {
  const UpdateEvent({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.occurredAt,
    required this.observedAt,
    this.content,
    this.creator,
    this.followKey,
    this.scheduleChange,
    this.read = false,
    this.archived = false,
  });

  /// Stable across polls. See [UpdateIds].
  final String id;
  final UpdateKind kind;
  final String title;
  final String subtitle;

  /// When the thing happened at the source — a publish time or an event start.
  /// Ordering uses this, so a late poll does not push old items to the top.
  final DateTime occurredAt;

  /// When this app first saw it. Kept separate from [occurredAt] so a backfill
  /// is recognisable as a backfill rather than a burst of fresh activity.
  final DateTime observedAt;

  /// The video an update points at, when it has one.
  final ContentIdentity? content;
  final LocalSubscription? creator;
  final CalendarFollowKey? followKey;
  final ScheduleChange? scheduleChange;

  /// Explicit user state. Opening a video does not imply either.
  final bool read;
  final bool archived;

  UpdateEvent copyWith({bool? read, bool? archived}) => UpdateEvent(
    id: id,
    kind: kind,
    title: title,
    subtitle: subtitle,
    occurredAt: occurredAt,
    observedAt: observedAt,
    content: content,
    creator: creator,
    followKey: followKey,
    scheduleChange: scheduleChange,
    read: read ?? this.read,
    archived: archived ?? this.archived,
  );
}

/// How far a source has been read, per source.
///
/// A cursor is per source so one failing creator cannot roll the others back,
/// and `baseline` records that the source has been seen at least once. The
/// first read of a source establishes the baseline and produces no events: a
/// user who just subscribed to a creator with 800 videos wants to be told about
/// the next one, not all 800.
class UpdateCursor {
  const UpdateCursor({
    required this.sourceKey,
    required this.baselineAt,
    this.lastOccurredAt,
    this.lastId,
  });

  /// Identifies the upstream the cursor belongs to, e.g. one creator MID or one
  /// calendar URL.
  final String sourceKey;

  /// When this source was first read. Null is impossible here — a cursor row
  /// exists only after a successful first read.
  final DateTime baselineAt;

  /// The newest [UpdateEvent.occurredAt] already turned into events.
  final DateTime? lastOccurredAt;

  /// Breaks ties when several items share [lastOccurredAt].
  final String? lastId;

  /// Whether [occurredAt]/[id] is newer than what this cursor has consumed.
  bool accepts(DateTime occurredAt, String id) {
    final last = lastOccurredAt;
    if (last == null) return occurredAt.isAfter(baselineAt);
    if (occurredAt.isAfter(last)) return true;
    if (occurredAt.isBefore(last)) return false;
    final tie = lastId;
    return tie == null ? false : id.compareTo(tie) > 0;
  }
}

/// The result of one collection pass over the sources.
///
/// Failures are per source and carried alongside the events: a creator that
/// timed out must not look like a creator with nothing new, and it must not
/// discard what the other creators produced.
class UpdateHarvest {
  UpdateHarvest({
    required List<UpdateEvent> events,
    required Map<String, UpdateCursor> cursors,
    required Set<String> failedSources,
    this.baselinedSources = const {},
  }) : events = List.unmodifiable(events),
       cursors = Map.unmodifiable(cursors),
       failedSources = Set.unmodifiable(failedSources);

  final List<UpdateEvent> events;

  /// Cursors to advance, only for sources that were read successfully.
  final Map<String, UpdateCursor> cursors;

  /// Sources that could not be read this pass. Their cursors stay where they
  /// were, so the next pass retries from the same point.
  final Set<String> failedSources;

  /// Sources whose baseline was established by this pass. They deliberately
  /// contribute no events.
  final Set<String> baselinedSources;

  bool get isEmpty => events.isEmpty;
  bool get partial => failedSources.isNotEmpty;
}
