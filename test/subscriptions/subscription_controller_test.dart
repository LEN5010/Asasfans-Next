import 'dart:async';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/core/storage/storage_failure.dart';
import 'package:asasfans_next/features/creator/domain/creator_repository.dart';
import 'package:asasfans_next/features/subscriptions/application/subscription_feed_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/subscriptions_fixture.dart';

void main() {
  late UpdateSource source;
  late MemoryUpdateStore store;
  late StreamController<int> changes;
  late SubscriptionFeedController controller;
  setUp(() {
    source = UpdateSource()..rows['1'] = [updateVideo(1)];
    store = MemoryUpdateStore(['1']);
    changes = StreamController<int>.broadcast();
    controller = SubscriptionFeedController(source, store, changes.stream);
  });
  tearDown(() async {
    controller.dispose();
    await store.close();
    await changes.close();
  });
  test(
    'receipt read failure retains pending network slice; retry cannot skip it',
    () async {
      store.readFailure = const StorageFailure(StorageFailureKind.unavailable);
      await controller.refresh();
      expect(controller.items, isEmpty);
      expect(source.calls, hasLength(1));
      await controller.loadMore(automatic: true);
      expect(source.calls, hasLength(1));
      store.readFailure = null;
      await controller.loadMore();
      expect(controller.items.single.title, '更新 1');
      expect(source.calls, hasLength(1));
      expect(controller.readsReady, isTrue);
    },
  );
  test(
    'membership replacement during network discards removed creator and requires refresh',
    () async {
      final pending = Completer<CreatorArchivePage>();
      source.handler = (_, _, _) => pending.future;
      final request = controller.refresh();
      await Future<void>.delayed(Duration.zero);
      store.snapshot = updateRoster(['2'], revision: 2);
      pending.complete(source.pageFor('1', 1));
      await request;
      expect(controller.items, isEmpty);
      expect(controller.needsRefresh, isTrue);
      source.handler = null;
      await controller.refresh();
      expect(controller.needsRefresh, isFalse);
      expect(source.calls.last.$1, '2');
    },
  );
  test('late old responses cannot overwrite refreshed membership', () async {
    final pending = Completer<CreatorArchivePage>();
    RequestCancellation? old;
    source.handler = (query, page, cancel) {
      old = cancel;
      return pending.future;
    };
    final first = controller.refresh();
    await Future<void>.delayed(Duration.zero);
    source.handler = null;
    source.rows['2'] = [updateVideo(2)];
    store.snapshot = updateRoster(['2'], revision: 1);
    await controller.refresh();
    expect(old?.isCancelled, isTrue);
    pending.complete(source.pageFor('1', 1));
    await first;
    expect(controller.items.single.title, '更新 2');
  });
  test(
    'failed receipt writes do not lie, reading is not playback or subscription removal',
    () async {
      await controller.refresh();
      final id = controller.items.single.identity.value;
      store.writeFailure = const StorageFailure(StorageFailureKind.unavailable);
      await expectLater(
        controller.mark([id], read: true),
        throwsA(isA<StorageFailure>()),
      );
      expect(controller.readStates[id], isNot(true));
      expect(controller.savingReads, isFalse);
      store.writeFailure = null;
      await controller.mark([id], read: true);
      expect(controller.readStates[id], isTrue);
      expect(store.snapshot.creators, hasLength(1));
      await controller.mark([id], read: false);
      expect(controller.readStates[id], isFalse);
    },
  );
  test(
    '429 pauses automatic loading; explicit retry uses retained heads',
    () async {
      source.failures['1'] = const ApiFailure(ApiFailureKind.rateLimited);
      await controller.refresh();
      expect(controller.failure?.kind, ApiFailureKind.rateLimited);
      await controller.loadMore(automatic: true);
      expect(source.calls, hasLength(1));
      source.failures.clear();
      await controller.loadMore();
      expect(controller.items, hasLength(1));
    },
  );
  test(
    'dispose cancels in flight and never notifies for late response',
    () async {
      final pending = Completer<CreatorArchivePage>();
      RequestCancellation? cancel;
      source.handler = (_, _, c) {
        cancel = c;
        return pending.future;
      };
      var notifications = 0;
      controller.addListener(() => notifications++);
      final request = controller.refresh();
      await Future<void>.delayed(Duration.zero);
      final before = notifications;
      controller.dispose();
      expect(cancel?.isCancelled, isTrue);
      pending.complete(source.pageFor('1', 1));
      await request;
      expect(notifications, before);
    },
  );
}
