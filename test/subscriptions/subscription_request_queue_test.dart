import 'dart:async';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/creator/domain/creator_repository.dart';
import 'package:asasfans_next/features/subscriptions/application/subscription_request_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/subscriptions_fixture.dart';

void main() {
  test(
    'requests serialize; a cancelled queued request never reaches transport and failure does not poison queue',
    () async {
      final source = UpdateSource();
      final pending = Completer<CreatorArchivePage>();
      source.handler = (_, _, _) => pending.future;
      final queue = SubscriptionRequestQueue(source, gap: Duration.zero);
      final first = queue.archives(const CreatorArchiveQuery(mid: '1'));
      final cancel = RequestCancellation();
      final second = queue.archives(
        const CreatorArchiveQuery(mid: '2'),
        cancellation: cancel,
      );
      final failed = expectLater(
        second,
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.cancelled,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(source.calls, [('1', 1)]);
      cancel.cancel();
      pending.complete(source.pageFor('1', 1));
      await first;
      await failed;
      source.handler = null;
      await queue.archives(const CreatorArchiveQuery(mid: '3'));
      expect(source.calls, [('1', 1), ('3', 1)]);
    },
  );
}
