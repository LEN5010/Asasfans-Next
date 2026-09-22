import '../../library/domain/library_models.dart';

/// One local reminder the app intends the system to show.
///
/// It is derived state: the followed occurrences and the user's lead time
/// decide it entirely, so it is recomputed rather than accumulated. That is
/// what makes a rescheduled or cancelled event correct by construction instead
/// of needing a separate "unschedule the old one" path that can be missed.
///
/// Nothing here is a delivered notification. A scheduled reminder says the app
/// asked the system to show something later; whether it appears depends on
/// permissions, power settings and the device being on.
class ScheduledReminder {
  const ScheduledReminder({
    required this.key,
    required this.fireAt,
    required this.title,
    required this.body,
    required this.sequence,
  });

  /// The occurrence this belongs to. One occurrence has at most one reminder,
  /// so a single owner is responsible for it and two code paths cannot both
  /// schedule the same event.
  final CalendarFollowKey key;

  /// When the system should show it, in UTC.
  final DateTime fireAt;

  final String title;
  final String body;

  /// The revision this was built from. A reminder built from an older revision
  /// is replaced rather than left beside the new one.
  final int sequence;

  /// A stable integer id, because the platform plugins key notifications by
  /// int rather than by string.
  ///
  /// Derived from the occurrence identity so the same occurrence always maps to
  /// the same id and rescheduling replaces rather than duplicates. Collisions
  /// between different occurrences are possible in principle; they cost a
  /// replaced reminder, never a wrong one fired at the wrong time, because the
  /// payload is rewritten along with the schedule.
  int get id {
    final source = '${key.source}|${key.uid}|${key.recurrenceId ?? ''}';
    // A bounded non-negative hash: plugins reject ids outside the 32-bit range.
    return source.hashCode & 0x3FFFFFFF;
  }

  @override
  bool operator ==(Object other) =>
      other is ScheduledReminder &&
      other.key == key &&
      other.fireAt == fireAt &&
      other.title == title &&
      other.body == body &&
      other.sequence == sequence;

  @override
  int get hashCode => Object.hash(key, fireAt, title, body, sequence);
}

/// How far ahead of an event its reminder fires.
enum ReminderLead {
  none(Duration.zero, '不提醒'),
  atStart(Duration.zero, '开始时'),
  fiveMinutes(Duration(minutes: 5), '提前 5 分钟'),
  fifteenMinutes(Duration(minutes: 15), '提前 15 分钟'),
  thirtyMinutes(Duration(minutes: 30), '提前 30 分钟'),
  oneHour(Duration(hours: 1), '提前 1 小时'),
  oneDay(Duration(days: 1), '提前 1 天');

  const ReminderLead(this.before, this.label);
  final Duration before;
  final String label;

  bool get enabled => this != ReminderLead.none;
}

/// Decides which reminders should exist right now.
///
/// Pure and total: given the follows, the setting and the current time it
/// returns the complete intended set. The caller diffs that against what is
/// scheduled, so a cancelled event's reminder disappears because it is no
/// longer produced — not because something remembered to withdraw it.
abstract final class ReminderPlan {
  /// Reminders for [follows], excluding the ones that should not exist.
  ///
  /// An occurrence is skipped when the source cancelled it, when its fire time
  /// has already passed, or when the user turned reminders off. A past event
  /// is deliberately not fired late: a reminder for something that already
  /// started is noise, and the plan forbids re-announcing expired events.
  static List<ScheduledReminder> from({
    required List<CalendarFollow> follows,
    required ReminderLead lead,
    required DateTime now,
  }) {
    if (!lead.enabled) return const [];
    final reminders = <ScheduledReminder>[];
    final seen = <CalendarFollowKey>{};
    for (final follow in follows) {
      final event = follow.event;
      if (event.isCancelled) continue;
      // One reminder per occurrence. A duplicate follow row must not become a
      // second notification for the same thing.
      if (!seen.add(follow.key)) continue;
      final fireAt = event.start.toUtc().subtract(lead.before);
      if (!fireAt.isAfter(now)) continue;
      reminders.add(
        ScheduledReminder(
          key: follow.key,
          fireAt: fireAt,
          title: event.title,
          body: _body(event.start, lead),
          sequence: event.sequence,
        ),
      );
    }
    return reminders;
  }

  static String _body(DateTime start, ReminderLead lead) {
    final local = start.toLocal();
    final time =
        '${local.month}月${local.day}日 '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    return lead == ReminderLead.atStart ? '$time 开始' : '$time 开始，${lead.label}';
  }
}

/// What has to change to make the scheduled set match the intended one.
///
/// Reminders whose content and time are unchanged are left alone rather than
/// cancelled and re-added, so an ordinary calendar refresh does not churn every
/// pending notification the device holds.
class ReminderDiff {
  const ReminderDiff({required this.schedule, required this.cancel});

  /// Reminders to hand to the platform. Replacing an existing id is how a
  /// rescheduled event moves, which keeps one owner per occurrence.
  final List<ScheduledReminder> schedule;

  /// Ids to withdraw: cancelled, moved into the past, or no longer followed.
  final List<int> cancel;

  bool get isEmpty => schedule.isEmpty && cancel.isEmpty;

  static ReminderDiff between({
    required List<ScheduledReminder> current,
    required List<ScheduledReminder> intended,
  }) {
    final byId = {for (final reminder in current) reminder.id: reminder};
    final wanted = {for (final reminder in intended) reminder.id: reminder};
    return ReminderDiff(
      schedule: [
        for (final reminder in intended)
          if (byId[reminder.id] != reminder) reminder,
      ],
      cancel: [
        for (final id in byId.keys)
          if (!wanted.containsKey(id)) id,
      ],
    );
  }
}
