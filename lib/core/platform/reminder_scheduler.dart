import '../../features/reminders/domain/scheduled_reminder.dart';

/// Whether the system will show local reminders.
enum ReminderPermission {
  /// The user allowed notifications.
  granted,

  /// The user has not been asked, or said no.
  denied,

  /// This build has no notification capability wired up at all.
  ///
  /// Distinct from denied on purpose: a permission prompt would not help, and
  /// the UI must not offer one. The app says reminders are unavailable rather
  /// than implying the user withheld something.
  unavailable,
}

/// The platform side of local reminders.
///
/// Local only. Nothing here contacts a server, registers a push token or
/// uploads what the user follows: the calendar was already synchronised, so
/// the device knows when a followed event starts without anyone telling it.
///
/// A scheduled reminder is a request to the system, not a delivery. Whether it
/// appears depends on permission, power management and the device being on,
/// and none of those are observable from here.
abstract interface class ReminderScheduler {
  Future<ReminderPermission> permission();

  /// Asks for notification permission, returning the resulting state.
  Future<ReminderPermission> requestPermission();

  /// Applies [diff]: cancels withdrawn ids, then schedules the rest.
  ///
  /// Scheduling an id that already exists replaces it, which is how a moved
  /// event stays a single reminder rather than becoming two.
  Future<void> apply(ReminderDiff diff);

  /// Everything currently pending, so the intended set can be diffed against
  /// what the system actually holds rather than against a local guess that a
  /// reboot or an OS cleanup may have invalidated.
  Future<List<int>> pending();

  /// Withdraws every reminder this app scheduled.
  Future<void> cancelAll();
}

/// The build with no notification plugin.
///
/// Reports [ReminderPermission.unavailable] and does nothing. Reminders are
/// planned and diffed regardless, so wiring a real scheduler later is a matter
/// of replacing this sink — the decision of what should fire is already made
/// and tested above it.
class UnavailableReminderScheduler implements ReminderScheduler {
  const UnavailableReminderScheduler();

  @override
  Future<ReminderPermission> permission() async =>
      ReminderPermission.unavailable;

  @override
  Future<ReminderPermission> requestPermission() async =>
      ReminderPermission.unavailable;

  @override
  Future<void> apply(ReminderDiff diff) async {}

  @override
  Future<List<int>> pending() async => const [];

  @override
  Future<void> cancelAll() async {}
}
