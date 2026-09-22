import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/platform/return_entry_service.dart';
import '../domain/return_session.dart';

/// Owns the floating return entry's session life.
///
/// The controller exists to keep two returns apart that the OS reports
/// identically: coming back from Bilibili, and coming back from the permission
/// screen. Without that distinction a session tears itself down the instant the
/// permission screen closes, or loops straight back out to Bilibili — both
/// failures the plan calls out by name.
///
/// It never starts itself. There is no boot receiver, no restart-on-kill and no
/// retry: a session begins from an explicit user handoff in the foreground and
/// ends for good.
class ReturnEntryController extends ChangeNotifier {
  ReturnEntryController(this._service) {
    _taps = _service.taps.listen(_onTap);
  }

  final ReturnEntryService _service;
  late final StreamSubscription<String> _taps;

  ReturnSession _session = ReturnSession.none;
  ReturnEntryCapability? _capability;
  bool _closed = false;

  /// True while the user is away at the system permission screen, so the
  /// resume it produces is not mistaken for a return from Bilibili.
  bool _awaitingPermission = false;

  /// Set when the user turns the entry on. Without an explicit opt-in no
  /// overlay is ever created, whatever the permission state happens to be.
  bool enabled = false;

  ReturnSession get session => _session;
  ReturnEntryCapability? get capability => _capability;
  bool get awaitingPermission => _awaitingPermission;

  /// Every notification goes through here.
  ///
  /// The platform calls this controller awaits are the points where disposal
  /// can land: a screen can go away while a permission check or an overlay
  /// request is still in flight, and notifying after that throws. Guarding in
  /// one place means a new await cannot reintroduce the gap.
  void _notify() {
    if (_closed) return;
    notifyListeners();
  }

  /// Called when the user taps the entry. Exposed so the app can restore the
  /// context the tap refers to; the controller itself does no navigation.
  void Function(String sessionId)? onReturnRequested;

  Future<ReturnEntryCapability> refreshCapability() async {
    final result = await _service.capability();
    if (_closed) return result;
    _capability = result;
    _notify();
    return result;
  }

  /// Turns the feature on, asking for the permission if that is what is
  /// missing.
  ///
  /// A refusal leaves the feature off and the app fully usable: handoffs still
  /// work and the ordinary system back still returns. The plan forbids both
  /// blocking the app and re-prompting in a loop, so a denied request simply
  /// reports the current state.
  Future<bool> enable() async {
    final capability = await refreshCapability();
    if (capability.available) {
      enabled = true;
      _notify();
      return true;
    }
    if (capability.block != ReturnEntryBlock.permissionMissing) {
      // Nothing to request: the platform or the OS version is the limit, and
      // sending the user to a settings screen would not change it.
      enabled = false;
      _notify();
      return false;
    }
    _awaitingPermission = true;
    _notify();
    await _service.requestPermission();
    // Deliberately not resolved here. The permission screen's own return is
    // what settles this, through [settlePermissionReturn].
    return false;
  }

  /// Re-reads the permission after the user comes back from the settings
  /// screen.
  ///
  /// This is the only resume that may be interpreted as a permission outcome.
  /// Any other resume is a return from wherever the user actually was.
  Future<void> settlePermissionReturn() async {
    if (!_awaitingPermission) return;
    _awaitingPermission = false;
    final capability = await refreshCapability();
    enabled = capability.available;
    _notify();
  }

  void disable() {
    enabled = false;
    unawaited(_end(ReturnEntryEnd.dismissed));
  }

  /// Prepares an entry for a handoff that is about to happen.
  ///
  /// Called while the app is still in the foreground and before the system is
  /// asked to open anything, because a newer Android will not start the
  /// backing service from the background without an already-visible overlay.
  ///
  /// A platform refusal is not a handoff failure. The session continues without
  /// an overlay, and the user returns through the app switcher as they always
  /// could.
  Future<void> prepare(String sessionId) async {
    if (_closed || !enabled || sessionId.isEmpty) return;
    // A new handoff replaces whatever came before; two entries would leave one
    // of them pointing at a session nobody can return through.
    if (_session.active) await _end(ReturnEntryEnd.dismissed);
    _session = ReturnSession(id: sessionId, state: ReturnEntryState.preparing);
    _notify();
    final shown = await _service.show(sessionId);
    if (_closed || _session.id != sessionId) return;
    _session = _session.copyWith(visible: shown);
    _notify();
  }

  /// Confirms the system took the handoff, so the entry is now the way back.
  Future<void> dispatched(String sessionId) async {
    if (_closed || _session.id != sessionId || !_session.active) return;
    _session = _session.copyWith(state: ReturnEntryState.external);
    _notify();
  }

  /// The handoff never happened, so there is nothing to return from.
  Future<void> abandon(String sessionId, {bool failed = true}) async {
    if (_session.id != sessionId) return;
    await _end(
      failed ? ReturnEntryEnd.handoffFailed : ReturnEntryEnd.dismissed,
    );
  }

  /// The user came back by some other route — app switcher, system back, or
  /// the desktop window.
  ///
  /// The entry has done its job and is removed. Restoring the context is the
  /// restorer's business and happens the same way regardless of how the user
  /// got here, which is exactly the platform-independent contract the plan
  /// requires.
  Future<void> returnedElsewhere() async {
    if (_awaitingPermission) return;
    if (!_session.active) return;
    await _end(ReturnEntryEnd.returnedElsewhere);
  }

  void _onTap(String sessionId) {
    // A tap from a session that already ended is a stale overlay the platform
    // has not torn down yet. Ignoring it stops one system callback from driving
    // a second restore.
    if (_closed || sessionId != _session.id || !_session.active) return;
    _session = _session.copyWith(state: ReturnEntryState.returning);
    _notify();
    onReturnRequested?.call(sessionId);
    unawaited(_end(ReturnEntryEnd.returned));
  }

  Future<void> _end(ReturnEntryEnd reason) async {
    if (_session.state == ReturnEntryState.disabled && _session.id.isEmpty) {
      return;
    }
    _session = _session.copyWith(
      state: ReturnEntryState.ended,
      end: reason,
      visible: false,
    );
    _notify();
    // Always asked for, even when the overlay was never shown: a refused show
    // may still have left a service running.
    await _service.hide();
  }

  @override
  void dispose() {
    _closed = true;
    unawaited(_taps.cancel());
    unawaited(_service.hide());
    super.dispose();
  }
}
