import 'dart:async';
import 'package:asasfans_next/features/account/application/login_browser_lifecycle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'closing immediately blocks navigation and waits for pending setup',
    () async {
      final lifecycle = LoginBrowserLifecycle();
      final prepared = Completer<void>();
      final events = <String>[];
      final setup = lifecycle.initialize(() async {
        events.add('prepare');
        await prepared.future;
        if (lifecycle.acceptsNavigation) events.add('load-login');
      });
      final close = lifecycle.close(() async => events.add('stop'));
      expect(lifecycle.acceptsNavigation, isFalse);
      expect(lifecycle.isClosed, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(events, ['prepare']);
      prepared.complete();
      await Future.wait([setup, close]);
      expect(events, ['prepare', 'stop']);
      expect(lifecycle.isClosed, isTrue);
      await lifecycle.initialize(() async => events.add('reopen'));
      expect(events, ['prepare', 'stop']);
    },
  );

  test(
    'concurrent cleanup is coalesced; a failed stop is not a closed browser',
    () async {
      final lifecycle = LoginBrowserLifecycle();
      final stopping = Completer<void>();
      var attempts = 0;
      final close = lifecycle.close(() async {
        attempts++;
        await stopping.future;
      });
      final other = lifecycle.close(() async => attempts++);
      final failed = expectLater(close, throwsStateError);
      final otherFailed = expectLater(other, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      stopping.completeError(StateError('fixture stop failure'));
      await Future.wait([failed, otherFailed]);
      expect(attempts, 1);
      expect(lifecycle.isClosed, isFalse);
      expect(lifecycle.acceptsNavigation, isFalse);
      await lifecycle.close(() async => attempts++);
      expect(lifecycle.isClosed, isTrue);
      expect(attempts, 2);
      await lifecycle.close(() async => attempts++);
      expect(attempts, 2);
    },
  );

  test('partial setup failure still requires shutdown', () async {
    final lifecycle = LoginBrowserLifecycle();
    await expectLater(
      lifecycle.initialize(() async => throw StateError('partial setup')),
      throwsStateError,
    );
    var stopped = false;
    await lifecycle.close(() async => stopped = true);
    expect(stopped, isTrue);
    expect(lifecycle.isClosed, isTrue);
  });

  test('late reload cannot undo terminal blank navigation', () async {
    final lifecycle = LoginBrowserLifecycle();
    await lifecycle.initialize(() async {});
    final reload = Completer<void>();
    final events = <String>[];
    final navigation = lifecycle.navigate(() async {
      events.add('reload');
      await reload.future;
      events.add('reload-ack');
    });
    await Future<void>.delayed(Duration.zero);
    final queued = lifecycle.navigate(() async => events.add('queued'));
    final close = lifecycle.close(() async => events.add('blank'));
    reload.complete();
    await Future.wait([navigation, queued, close]);
    expect(events, ['reload', 'reload-ack', 'blank']);
  });
}
