/// Where one floating-return session is in its life.
///
/// The states exist to keep two things apart that look alike from inside the
/// app: coming back from Bilibili, and coming back from the permission screen.
/// An `onResume` is not an external-playback-finished event, and treating
/// every resume as a return is what makes an entry tear itself down the moment
/// it appears.
enum ReturnEntryState {
  /// The user has not turned the entry on, or turned it off.
  disabled,

  /// A handoff is being set up while the app is still in the foreground. The
  /// overlay must be created here: a newer Android refuses a background start
  /// without an already-visible overlay.
  preparing,

  /// The system accepted the handoff and the entry is available.
  external,

  /// The user asked to come back and the restore is running.
  returning,

  /// Finished, refused or invalidated. A session never restarts itself.
  ended,
}

/// Why a session finished, for the caller that has to explain it.
enum ReturnEntryEnd {
  /// The user came back through the entry.
  returned,

  /// The user came back some other way — app switcher, system back, the
  /// desktop window. The plan requires this to restore exactly the same
  /// context, so it is an ordinary ending rather than a failure.
  returnedElsewhere,

  /// The user dismissed the entry.
  dismissed,

  /// The platform refused to show it, or the permission went away.
  unavailable,

  /// The handoff itself failed, so there is nothing to come back from.
  handoffFailed,
}

/// One floating-return session.
///
/// It holds only what the entry needs: which handoff it belongs to and where it
/// is in its life. It carries no content, no query and no scroll position —
/// that is the return context's job, and duplicating it here would create a
/// second copy to keep in sync.
class ReturnSession {
  const ReturnSession({
    required this.id,
    required this.state,
    this.end,
    this.visible = false,
  });

  /// The handoff session this belongs to. A tap carrying a different id is
  /// from a session already finished, and is ignored rather than restoring.
  final String id;
  final ReturnEntryState state;
  final ReturnEntryEnd? end;

  /// Whether the platform currently has an overlay up for this session.
  /// Distinct from the state: a session can be [ReturnEntryState.external]
  /// with no overlay when the platform refused it, and the handoff is still
  /// perfectly usable that way.
  final bool visible;

  static const none = ReturnSession(id: '', state: ReturnEntryState.disabled);

  bool get active =>
      state == ReturnEntryState.preparing || state == ReturnEntryState.external;

  ReturnSession copyWith({
    ReturnEntryState? state,
    ReturnEntryEnd? end,
    bool? visible,
  }) => ReturnSession(
    id: id,
    state: state ?? this.state,
    end: end ?? this.end,
    visible: visible ?? this.visible,
  );
}
