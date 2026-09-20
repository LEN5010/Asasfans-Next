import 'dart:async';

import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/core/network/rate_limit_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;
  late RateLimitGate gate;
  setUp(() {
    now = DateTime.utc(2026, 9, 21);
    gate = RateLimitGate(clock: () => now);
  });

  test(
    'cooldown rejects all callers without dispatching or extending it',
    () async {
      var calls = 0;
      Future<void> request() async {
        calls++;
        throw const ApiFailure(
          ApiFailureKind.rateLimited,
          retryAfter: Duration(minutes: 2),
        );
      }

      final deadline = now.add(const Duration(minutes: 2));
      final limited = throwsA(
        isA<ApiFailure>().having((e) => e.retryAt, 'deadline', deadline),
      );
      await expectLater(gate.run(request), limited);
      now = now.add(const Duration(minutes: 1));
      for (var i = 0; i < 3; i++) {
        await expectLater(gate.run(request), limited);
      }
      expect(calls, 1);
      now = deadline;
      expect(await gate.run(() async => 'ready'), 'ready');
    },
  );

  test('missing guidance backs off and success resets the fallback', () async {
    Future<void> limited() async =>
        throw const ApiFailure(ApiFailureKind.rateLimited);
    for (final seconds in [30, 60, 120, 240, 480, 480]) {
      await expectLater(
        gate.run(limited),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.retryAfter,
            'delay',
            Duration(seconds: seconds),
          ),
        ),
      );
      now = now.add(Duration(seconds: seconds));
    }
    await gate.run(() async => null);
    await expectLater(
      gate.run(limited),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.retryAfter,
          'reset delay',
          const Duration(seconds: 30),
        ),
      ),
    );
  });

  test('an older concurrent success does not erase a new cooldown', () async {
    final response = Completer<void>();
    final old = gate.run(() => response.future);
    await expectLater(
      gate.run<void>(() async {
        throw const ApiFailure(
          ApiFailureKind.rateLimited,
          retryAfter: Duration(seconds: 60),
        );
      }),
      throwsA(isA<ApiFailure>()),
    );
    response.complete();
    await old;
    var dispatched = false;
    await expectLater(
      gate.run(() async {
        dispatched = true;
      }),
      throwsA(isA<ApiFailure>()),
    );
    expect(dispatched, isFalse);
  });

  test('ordinary failures are not converted into cooldowns', () async {
    await expectLater(
      gate.run<void>(() async {
        throw const ApiFailure(ApiFailureKind.offline);
      }),
      throwsA(
        isA<ApiFailure>().having((e) => e.kind, 'kind', ApiFailureKind.offline),
      ),
    );
    expect(await gate.run(() async => 42), 42);
  });
}
