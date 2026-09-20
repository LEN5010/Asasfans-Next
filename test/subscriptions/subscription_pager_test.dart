import 'dart:async';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/creator/domain/creator_repository.dart';
import 'package:asasfans_next/features/subscriptions/application/subscription_pager.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/subscriptions_fixture.dart';

void main() {
  test(
    'k-way merge reaches every UP second page; bounded rounds retain frontier, dedup and order',
    () async {
      final source = UpdateSource();
      source.rows['1'] = List.generate(
        35,
        (i) => updateVideo(i, seconds: 10000 - i * 2, mid: '1'),
      );
      source.rows['2'] = [
        source.rows['1']![5],
        ...List.generate(
          34,
          (i) => updateVideo(100 + i, seconds: 9999 - i * 2, mid: '2'),
        ),
      ]..sort((a, b) => b.publishedAt!.compareTo(a.publishedAt!));
      final pager = SubscriptionPager(
        source,
        updateRoster(['1', '2']),
        requestBudget: 1,
        outputSize: 12,
      );
      final first = await pager.next();
      expect(first.items, isEmpty);
      expect(first.hasMore, isTrue);
      expect(first.checkedCreators, 1);
      final all = <VideoSummary>[];
      for (var attempts = 0; attempts < 20; attempts++) {
        final before = source.calls.length;
        final page = await pager.next();
        expect(source.calls.length - before, lessThanOrEqualTo(1));
        all.addAll(page.items);
        if (!page.hasMore) break;
      }
      expect(all, hasLength(69));
      expect(all.map((v) => v.identity).toSet(), hasLength(69));
      expect(source.calls, containsAll([('1', 2), ('2', 2)]));
      for (var index = 1; index < all.length; index++) {
        expect(
          all[index].publishedAt!.isAfter(all[index - 1].publishedAt!),
          isFalse,
        );
      }
      expect(all.first.creatorId, '1');
    },
  );
  test(
    'one failed UP does not hide healthy rows; retry replays cached prefixes without refetch',
    () async {
      final source = UpdateSource()
        ..rows['1'] = [updateVideo(1, seconds: 10)]
        ..rows['2'] = [updateVideo(2, seconds: 20)]
        ..failures['2'] = const ApiFailure(ApiFailureKind.riskControl);
      final pager = SubscriptionPager(source, updateRoster(['1', '2']));
      final first = await pager.next();
      expect(first.items.single.title, '更新 1');
      expect(first.issues.single.creator.mid, '2');
      expect(first.hasMore, isFalse);
      source.failures.clear();
      pager.rewindForRetry();
      final retried = await pager.next();
      expect(retried.items.map((v) => v.title), ['更新 2', '更新 1']);
      expect(retried.issues, isEmpty);
      expect(source.calls.where((c) => c.$1 == '1'), hasLength(1));
      expect(source.calls.where((c) => c.$1 == '2'), hasLength(2));
    },
  );
  test(
    '429 pauses all lanes and retains a successful head for explicit retry',
    () async {
      final source = UpdateSource()
        ..rows['1'] = [updateVideo(1)]
        ..rows['2'] = [updateVideo(2)]
        ..failures['2'] = const ApiFailure(
          ApiFailureKind.rateLimited,
          retryAfter: Duration(seconds: 60),
        );
      final pager = SubscriptionPager(source, updateRoster(['1', '2', '3']));
      final paused = await pager.next();
      expect(paused.pause?.kind, ApiFailureKind.rateLimited);
      expect(paused.items, isEmpty);
      expect(source.calls, [('1', 1), ('2', 1)]);
      source.failures.clear();
      final resumed = await pager.next();
      expect(resumed.items, hasLength(2));
      expect(source.calls.where((c) => c.$1 == '1'), hasLength(1));
    },
  );
  test(
    'changed total, overlap or missing pubdate is isolated and never treated as exhaustion',
    () async {
      final source = UpdateSource()
        ..rows['1'] = List.generate(31, (i) => updateVideo(i));
      final pager = SubscriptionPager(
        source,
        updateRoster(['1']),
        outputSize: 30,
      );
      expect((await pager.next()).items, hasLength(30));
      source.rows['1']!.add(updateVideo(40));
      final result = await pager.next();
      expect(result.items, isEmpty);
      expect(result.issues.single.failure.kind, ApiFailureKind.datasetChanged);
      expect(() => pager.rewindForRetry(), throwsA(isA<ApiFailure>()));
      final bad = UpdateSource()
        ..rows['1'] = [
          VideoSummary(
            identity: updateVideo(1).identity,
            title: '未知时间',
            creatorId: '1',
            creatorName: 'UP',
          ),
        ];
      final invalid = await SubscriptionPager(bad, updateRoster(['1'])).next();
      expect(
        invalid.issues.single.failure.kind,
        ApiFailureKind.invalidResponse,
      );
    },
  );
  test(
    'cancellation rolls back merge state; simultaneous next is rejected',
    () async {
      final source = UpdateSource()
        ..rows['1'] = [updateVideo(1)]
        ..rows['2'] = [updateVideo(2)];
      final pending = Completer<CreatorArchivePage>();
      source.handler = (query, page, cancel) async =>
          query.mid == '2' ? pending.future : source.pageFor(query.mid, page);
      final pager = SubscriptionPager(source, updateRoster(['1', '2']));
      final cancel = RequestCancellation();
      final request = pager.next(cancellation: cancel);
      await Future<void>.delayed(Duration.zero);
      await expectLater(pager.next(), throwsA(isA<ApiFailure>()));
      final failure = expectLater(
        request,
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.cancelled,
          ),
        ),
      );
      cancel.cancel();
      pending.complete(source.pageFor('2', 1));
      await failure;
      source.handler = null;
      final retried = await pager.next();
      expect(retried.items, hasLength(2));
      expect(source.calls.where((c) => c.$1 == '1'), hasLength(2));
    },
  );
}
