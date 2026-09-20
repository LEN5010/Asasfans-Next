/// Whether the source marked an occurrence as still happening.
enum EventStatus { confirmed, tentative, cancelled }

/// Display grouping, decided at presentation time.
///
/// The bot filters livestreams away at the source; the app keeps every event
/// and classifies here instead, so birthdays and anniversaries are never lost
/// from the stored model.
enum EventKind { live, other }

/// Keep source identity and recurrence identity separate from display text so
/// rescheduling does not silently create a second personal reminder.
class CalendarEvent {
  const CalendarEvent({
    required this.uid,
    required this.title,
    required this.start,
    required this.end,
    required this.allDay,
    this.recurrenceId,
    this.sequence = 0,
    this.status = EventStatus.confirmed,
    this.description = '',
    this.location = '',
    this.categories = const [],
    this.members = const [],
    this.sourceUrl,
  });

  final String uid;

  /// Distinguishes one occurrence of a recurring series from the others. Two
  /// occurrences share a uid but never an identity.
  final String? recurrenceId;

  /// Higher values supersede earlier revisions of the same occurrence.
  final int sequence;

  final String title;

  /// Instants for timed events. All-day events carry pure calendar dates and
  /// must not be compared by a local midnight timestamp.
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final EventStatus status;
  final String description;
  final String location;
  final List<String> categories;
  final List<String> members;
  final Uri? sourceUrl;

  bool get isCancelled => status == EventStatus.cancelled;

  /// Stable key for an occurrence. Rescheduling changes the start time but not
  /// this identity, so an existing reminder is updated rather than duplicated.
  String get identity => recurrenceId == null ? uid : '$uid/$recurrenceId';

  CalendarEvent copyWith({
    DateTime? start,
    DateTime? end,
    EventStatus? status,
  }) => CalendarEvent(
    uid: uid,
    title: title,
    start: start ?? this.start,
    end: end ?? this.end,
    allDay: allDay,
    recurrenceId: recurrenceId,
    sequence: sequence,
    status: status ?? this.status,
    description: description,
    location: location,
    categories: categories,
    members: members,
    sourceUrl: sourceUrl,
  );
}

/// Result of a calendar load, including how fresh it is.
///
/// A stale result is still shown; the UI says when it was last synced rather
/// than pretending an outdated list is current or blanking the view.
class CalendarSnapshot {
  const CalendarSnapshot({
    required this.events,
    required this.fetchedAt,
    this.fromCache = false,
  });

  final List<CalendarEvent> events;
  final DateTime fetchedAt;
  final bool fromCache;
}

abstract interface class CalendarRepository {
  /// All events overlapping the range, including all-day and cancelled ones.
  /// Filtering by kind belongs to the display layer.
  Future<CalendarSnapshot> events({
    required DateTime from,
    required DateTime until,
    bool forceRefresh = false,
  });
}
