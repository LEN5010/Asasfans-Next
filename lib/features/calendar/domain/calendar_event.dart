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
    this.cancelled = false,
    this.members = const [],
    this.sourceUrl,
  });

  final String uid;
  final String? recurrenceId;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final bool cancelled;
  final List<String> members;
  final Uri? sourceUrl;
}

abstract interface class CalendarRepository {
  Future<List<CalendarEvent>> events({
    required DateTime from,
    required DateTime until,
  });
}
