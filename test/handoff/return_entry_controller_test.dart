import 'dart:async';

import 'package:asasfans_next/core/platform/return_entry_service.dart';
import 'package:asasfans_next/features/handoff/application/return_entry_controller.dart';
import 'package:asasfans_next/features/handoff/domain/return_session.dart';
import 'package:flutter_test/flutter_test.dart';

/// A platform that records what it was asked to do, so the tests can check the
/// service was told to clean up rather than only that the Dart state changed.
class FakeReturnEntryService implements ReturnEntryService {
  FakeReturnEntryService({this.available = true, this.showSucceeds = true});

  bool available;
  bool showSucceeds;
  ReturnEntryBlock? block;
  int permissionRequests = 0;
  int hides = 0;
  final shown = <String>[];
  final _taps = StreamController<String>.broadcast();

  void tap(String sessionId) => _taps.add(sessionId);
  Future<void> close() => _taps.close();

  @override
  Future<ReturnEntryCapability> capability() async => available
      ? const ReturnEntryCapability(available: true)
      : ReturnEntryCapability(
          available: false,
          block: block ?? ReturnEntryBlock.permissionMissing,
        );

  @override
  Future<void> requestPermission() async => permissionRequests++;

  @override
  Future<bool> show(String sessionId) async {
    if (!showSucceeds) return false;
    shown.add(sessionId);
    return true;
  }

  @override
  Future<void> hide() async => hides++;

  @override
  Stream<String> get taps => _taps.stream;
}

void main() {
  late FakeReturnEntryService service;
  late ReturnEntryController controller;

  setUp(() {
    service = FakeReturnEntryService();
    controller = ReturnEntryController(service);
  });
  tearDown(() async {
    controller.dispose();
    await service.close();
  });

  Future<void> enabledSession(String id) async {
    await controller.enable();
    await controller.prepare(id);
    await controller.dispatched(id);
  }

  group('enabling', () {
    test('a granted permission enables it without a settings trip', () async {
      expect(await controller.enable(), isTrue);
      expect(controller.enabled, isTrue);
      expect(service.permissionRequests, 0);
    });

    test('a missing permission asks once and waits for the return', () async {
      service.available = false;
      expect(await controller.enable(), isFalse);
      expect(service.permissionRequests, 1);
      // Deliberately unresolved: the permission screen's own return settles it,
      // so nothing here claims a grant that has not happened.
      expect(controller.enabled, isFalse);
      expect(controller.awaitingPermission, isTrue);
    });

    test('an OS that cannot do it is not sent to a settings screen', () async {
      service
        ..available = false
        ..block = ReturnEntryBlock.osTooOld;
      expect(await controller.enable(), isFalse);
      // There is no permission that would change this, so asking for one would
      // send the user somewhere that cannot help.
      expect(service.permissionRequests, 0);
      expect(controller.awaitingPermission, isFalse);
    });

    test('granting at the settings screen enables it on return', () async {
      service.available = false;
      await controller.enable();
      service.available = true;
      await controller.settlePermissionReturn();
      expect(controller.enabled, isTrue);
      expect(controller.awaitingPermission, isFalse);
    });

    test(
      'refusing at the settings screen leaves it off, not asking again',
      () async {
        service.available = false;
        await controller.enable();
        await controller.settlePermissionReturn();
        expect(controller.enabled, isFalse);
        // One request per explicit user action: no loop back to the permission
        // screen just because the answer was no.
        expect(service.permissionRequests, 1);
      },
    );
  });

  group('session life', () {
    test('no entry is shown until the user turns it on', () async {
      await controller.prepare('s1');
      expect(service.shown, isEmpty);
      expect(controller.session.state, ReturnEntryState.disabled);
    });

    test('a prepared session becomes the way back once dispatched', () async {
      await enabledSession('s1');
      expect(service.shown, ['s1']);
      expect(controller.session.state, ReturnEntryState.external);
      expect(controller.session.visible, isTrue);
    });

    test('a refused overlay still leaves a usable handoff', () async {
      service.showSucceeds = false;
      await enabledSession('s1');
      // The trip out is unaffected; only the enhancement is missing.
      expect(controller.session.state, ReturnEntryState.external);
      expect(controller.session.visible, isFalse);
    });

    test('a failed handoff ends the session and clears the platform', () async {
      await controller.enable();
      await controller.prepare('s1');
      await controller.abandon('s1');
      expect(controller.session.state, ReturnEntryState.ended);
      expect(controller.session.end, ReturnEntryEnd.handoffFailed);
      expect(service.hides, greaterThan(0));
    });

    test('a second handoff replaces the first entry', () async {
      await enabledSession('s1');
      await controller.prepare('s2');
      expect(controller.session.id, 's2');
      // Two balls would leave one pointing at a session nobody can return
      // through.
      expect(service.shown, ['s1', 's2']);
      expect(service.hides, greaterThan(0));
    });
  });

  group('returning', () {
    test('a tap reports the session and ends it once', () async {
      await enabledSession('s1');
      final requested = <String>[];
      controller.onReturnRequested = requested.add;
      service.tap('s1');
      await Future<void>.delayed(Duration.zero);
      expect(requested, ['s1']);
      expect(controller.session.end, ReturnEntryEnd.returned);

      // A repeated system callback must not drive a second restore.
      service.tap('s1');
      await Future<void>.delayed(Duration.zero);
      expect(requested, ['s1']);
    });

    test('a tap from an older session is ignored', () async {
      await enabledSession('s1');
      final requested = <String>[];
      controller.onReturnRequested = requested.add;
      service.tap('stale');
      await Future<void>.delayed(Duration.zero);
      expect(requested, isEmpty);
      expect(controller.session.state, ReturnEntryState.external);
    });

    test('coming back another way ends the session too', () async {
      await enabledSession('s1');
      await controller.returnedElsewhere();
      expect(controller.session.end, ReturnEntryEnd.returnedElsewhere);
      expect(service.hides, greaterThan(0));
    });

    test(
      'returning from the permission screen does not end the session',
      () async {
        await enabledSession('s1');
        service.available = false;
        await controller.enable();
        // The resume that follows a permission request belongs to that request.
        // Treating it as a return would tear down the entry the user just set up.
        await controller.returnedElsewhere();
        expect(controller.session.state, ReturnEntryState.external);
      },
    );

    test('turning it off removes the entry immediately', () async {
      await enabledSession('s1');
      controller.disable();
      await Future<void>.delayed(Duration.zero);
      expect(controller.enabled, isFalse);
      expect(controller.session.state, ReturnEntryState.ended);
      expect(service.hides, greaterThan(0));
    });
  });
}
