import 'dart:async';
import 'package:asasfans_next/core/bilibili/wbi_key_cache.dart';
import 'package:asasfans_next/core/bilibili/wbi_signer.dart';
import 'package:asasfans_next/core/domain/request_cancellation.dart';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/bili_fixture.dart' show fixtureKeys;

final _cancelled = throwsA(
  isA<ApiFailure>().having((e) => e.kind, 'kind', ApiFailureKind.cancelled),
);
void main() {
  test(
    'nav flight coalesces; one cancelled waiter does not cancel another',
    () async {
      final pending = Completer<WbiKeys>();
      var calls = 0;
      late RequestCancellation transport;
      final cache = WbiKeyCache((cancel) {
        transport = cancel;
        calls++;
        return pending.future;
      });
      addTearDown(cache.close);
      final cancel = RequestCancellation();
      final first = cache.get(cancel);
      final second = cache.get(null);
      final failure = expectLater(first, _cancelled);
      cancel.cancel();
      await failure;
      expect(transport.isCancelled, isFalse);
      final keys = fixtureKeys();
      pending.complete(keys);
      expect(await second, same(keys));
      expect(await cache.get(null), same(keys));
      expect(calls, 1);
    },
  );
  test(
    'last cancellation aborts nav; late old completion cannot replace new cache',
    () async {
      final pending = <Completer<WbiKeys>>[];
      final cancellations = <RequestCancellation>[];
      final cache = WbiKeyCache((cancel) {
        cancellations.add(cancel);
        final call = Completer<WbiKeys>();
        pending.add(call);
        return call.future;
      });
      addTearDown(cache.close);
      final cancel = RequestCancellation();
      final first = cache.get(cancel);
      final failure = expectLater(first, _cancelled);
      cancel.cancel();
      await failure;
      expect(cancellations.first.isCancelled, isTrue);
      final second = cache.get(null);
      final fresh = fixtureKeys();
      pending[1].complete(fresh);
      expect(await second, same(fresh));
      pending.first.complete(fixtureKeys());
      await Future<void>.delayed(Duration.zero);
      expect(await cache.get(null), same(fresh));
    },
  );
  test(
    'TTL, rollback clock and failures never create immortal/stale cache',
    () async {
      var now = DateTime.utc(2026);
      var fail = false;
      var calls = 0;
      final cache = WbiKeyCache((_) async {
        calls++;
        if (fail) throw const ApiFailure(ApiFailureKind.offline);
        return fixtureKeys();
      }, clock: () => now);
      addTearDown(cache.close);
      await cache.get(null);
      await cache.get(null);
      expect(calls, 1);
      now = now.add(const Duration(hours: 1));
      fail = true;
      await expectLater(cache.get(null), throwsA(isA<ApiFailure>()));
      fail = false;
      await cache.get(null);
      expect(calls, 3);
      now = now.subtract(const Duration(days: 1));
      await cache.get(null);
      expect(calls, 4);
    },
  );
  test(
    'close resolves waiters even when loader ignores cancellation',
    () async {
      final pending = Completer<WbiKeys>();
      final cache = WbiKeyCache((_) => pending.future);
      final request = cache.get(null);
      final failure = expectLater(request, _cancelled);
      cache.close();
      await failure;
      pending.complete(fixtureKeys());
      await expectLater(cache.get(null), _cancelled);
    },
  );
}
