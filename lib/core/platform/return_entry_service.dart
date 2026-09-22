import 'package:flutter/services.dart';

/// Why a return entry cannot be shown.
///
/// Each reason is distinct because each has a different answer. Telling a user
/// their Android version cannot do this is honest; telling them to grant a
/// permission that does not exist on their device is not.
enum ReturnEntryBlock {
  /// The platform has no overlay return entry at all. Desktop and iOS report
  /// this: the plan deliberately does not promise an Android-style floating
  /// ball there, and a switch the platform cannot honour must not be offered.
  unsupported,

  /// The OS build is too old for the overlay window type this uses.
  osTooOld,

  /// The user has not granted the overlay permission, or revoked it.
  permissionMissing,
}

/// Whether this device can show a floating return entry, and why not.
class ReturnEntryCapability {
  const ReturnEntryCapability({required this.available, this.block});

  /// Available means the entry can be shown right now: supported platform,
  /// sufficient OS version and a granted permission. It is not a promise that
  /// the system will keep the overlay visible — it may resize, move or hide it.
  final bool available;

  /// Why not, when [available] is false.
  final ReturnEntryBlock? block;

  static const unsupported = ReturnEntryCapability(
    available: false,
    block: ReturnEntryBlock.unsupported,
  );
}

/// The platform side of the floating return entry.
///
/// It shows one small button that brings the user back to this app and nothing
/// else. It does not observe what the user is doing, does not read the screen,
/// and does not know Bilibili exists: it holds a session id and, when tapped,
/// asks the platform to bring this app's own task forward.
abstract interface class ReturnEntryService {
  /// What this device can do. Asked before offering the feature, so a switch
  /// is never shown for something the platform cannot honour.
  Future<ReturnEntryCapability> capability();

  /// Sends the user to the system permission screen.
  ///
  /// Returning from that screen is not returning from Bilibili, and this does
  /// not resolve to the granted state: the caller re-checks [capability]
  /// afterwards rather than assuming the trip succeeded.
  Future<void> requestPermission();

  /// Shows the entry for [sessionId].
  ///
  /// Called while this app is still in the foreground, because a newer Android
  /// requires an already-visible overlay before a background start. Returns
  /// false when the platform refused, which must degrade to an ordinary
  /// handoff rather than blocking it.
  Future<bool> show(String sessionId);

  /// Removes the entry and stops the service backing it.
  Future<void> hide();

  /// Fires when the user taps the entry, carrying the session id it was shown
  /// with. A session id that does not match the live one is ignored by the
  /// listener, so a stale entry cannot drive a restore.
  Stream<String> get taps;
}

/// The platform that has no such entry.
///
/// Desktop returns through its ordinary window and iOS through app switching;
/// both restore the same context, which is the contract the plan actually
/// requires. Presenting a disabled Android control on them would advertise a
/// capability that is not coming.
class UnsupportedReturnEntryService implements ReturnEntryService {
  const UnsupportedReturnEntryService();

  @override
  Future<ReturnEntryCapability> capability() async =>
      ReturnEntryCapability.unsupported;

  @override
  Future<void> requestPermission() async {}

  @override
  Future<bool> show(String sessionId) async => false;

  @override
  Future<void> hide() async {}

  @override
  Stream<String> get taps => const Stream.empty();
}

/// Talks to the Android return module over its own channel.
///
/// Deliberately separate from the login cookie channel: that one owns an
/// isolated WebView store, and folding an unrelated overlay service into it
/// would give both the other's reach.
class AndroidReturnEntryService implements ReturnEntryService {
  AndroidReturnEntryService({MethodChannel? methods, EventChannel? events})
    : _methods = methods ?? const MethodChannel(_channel),
      _events = events ?? const EventChannel('$_channel/taps');

  static const _channel = 'asasfans.next/return_entry';

  final MethodChannel _methods;
  final EventChannel _events;

  @override
  Future<ReturnEntryCapability> capability() async {
    try {
      final result = await _methods.invokeMapMethod<String, Object?>(
        'capability',
      );
      if (result == null) return ReturnEntryCapability.unsupported;
      if (result['available'] == true) {
        return const ReturnEntryCapability(available: true);
      }
      return ReturnEntryCapability(
        available: false,
        block: switch (result['block']) {
          'osTooOld' => ReturnEntryBlock.osTooOld,
          'permissionMissing' => ReturnEntryBlock.permissionMissing,
          _ => ReturnEntryBlock.unsupported,
        },
      );
    } on PlatformException {
      return ReturnEntryCapability.unsupported;
    } on MissingPluginException {
      return ReturnEntryCapability.unsupported;
    }
  }

  @override
  Future<void> requestPermission() async {
    try {
      await _methods.invokeMethod<void>('requestPermission');
    } on PlatformException {
      // The settings screen could not be opened. Capability is re-read by the
      // caller either way, so there is nothing to correct here.
    } on MissingPluginException {
      // Nothing to request.
    }
  }

  @override
  Future<bool> show(String sessionId) async {
    try {
      return await _methods.invokeMethod<bool>('show', {
            'sessionId': sessionId,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> hide() async {
    try {
      await _methods.invokeMethod<void>('hide');
    } on PlatformException {
      // A missing overlay is the state this asks for; failing to remove one
      // that is not there is not an error worth surfacing.
    } on MissingPluginException {
      // Nothing to hide.
    }
  }

  @override
  Stream<String> get taps => _events
      .receiveBroadcastStream()
      .map((event) => event is String ? event : '')
      .where((session) => session.isNotEmpty);
}
