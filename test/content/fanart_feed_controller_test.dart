import 'dart:async';

import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/content/application/fanart_feed_controller.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:flutter_test/flutter_test.dart';

FanartItem _item(String id) => FanartItem(
  identity: ContentIdentity(source: ContentSource.bilibiliDynamic, value: id),
  text: 'text-$id',
  authorName: 'author',
  authorUid: '1',
  images: const [],
  kind: FanartKind.fanart,
  contentType: FanartContentType.image,
  category: FanartCategory.normal,
  characterTags: const [],
);

/// Repository double driven by queued responses so ordering, cancellation and
/// generation behaviour can be exercised without any network access.
class _FakeRepository implements FanartRepository {
  final List<Completer<FanartPage>> pending = [];
  final List<({FanartQuery query, String? cursor})> calls = [];

  @override
  Future<FanartPage> page({
    FanartQuery query = const FanartQuery(),
    String? cursor,
    RequestCancellation? cancellation,
  }) {
    calls.add((query: query, cursor: cursor));
    final completer = Completer<FanartPage>();
    pending.add(completer);
    cancellation?.onCancel(() {
      if (!completer.isCompleted) {
        completer.completeError(const ApiFailure(ApiFailureKind.cancelled));
      }
    });
    return completer.future;
  }

  @override
  Future<FanartItem?> random({
    FanartQuery query = const FanartQuery(),
    RequestCancellation? cancellation,
  }) async => null;
}

void main() {
  late _FakeRepository repository;
  late FanartFeedController controller;

  setUp(() {
    repository = _FakeRepository();
    controller = FanartFeedController(repository);
  });

  tearDown(() => controller.dispose());

  test(
    'first page then append accumulates without losing earlier items',
    () async {
      final loading = controller.loadInitial();
      expect(controller.state.status, FeedStatus.loadingFirstPage);
      repository.pending.first.complete(
        FanartPage(items: [_item('a')], snapshotId: 's1', nextCursor: 'c1'),
      );
      await loading;

      expect(controller.state.status, FeedStatus.ready);
      expect(controller.state.canAppend, isTrue);

      final append = controller.loadMore();
      expect(controller.state.status, FeedStatus.appending);
      repository.pending[1].complete(
        const FanartPage(items: [], snapshotId: 's1'),
      );
      await append;

      expect(repository.calls[1].cursor, 'c1');
      expect(controller.state.items.map((i) => i.identity.value), ['a']);
      expect(controller.state.status, FeedStatus.endOfList);
      expect(controller.state.canAppend, isFalse);
    },
  );

  test(
    'concurrent loadMore calls issue only one request per generation',
    () async {
      final loading = controller.loadInitial();
      repository.pending.first.complete(
        FanartPage(items: [_item('a')], snapshotId: 's1', nextCursor: 'c1'),
      );
      await loading;

      final first = controller.loadMore();
      final second = controller.loadMore();
      expect(repository.calls.length, 2);

      repository.pending[1].complete(
        FanartPage(items: [_item('b')], snapshotId: 's1'),
      );
      await Future.wait([first, second]);
      expect(controller.state.items.map((i) => i.identity.value), ['a', 'b']);
    },
  );

  test(
    'a late response for an abandoned query never overwrites the new one',
    () async {
      final stale = controller.loadInitial();
      final replaced = controller.applyQuery(
        const FanartQuery(contentType: FanartContentType.video),
      );

      // The abandoned generation resolves after the new query was issued.
      repository.pending[1].complete(
        FanartPage(items: [_item('new')], snapshotId: 's2'),
      );
      await replaced;
      if (!repository.pending.first.isCompleted) {
        repository.pending.first.complete(
          FanartPage(items: [_item('old')], snapshotId: 's1'),
        );
      }
      await stale;

      expect(controller.state.items.map((i) => i.identity.value), ['new']);
      expect(controller.state.query.contentType, FanartContentType.video);
    },
  );

  test('append failure keeps existing items and allows retry', () async {
    final loading = controller.loadInitial();
    repository.pending.first.complete(
      FanartPage(items: [_item('a')], snapshotId: 's1', nextCursor: 'c1'),
    );
    await loading;

    final failing = controller.loadMore();
    repository.pending[1].completeError(
      const ApiFailure(ApiFailureKind.timeout),
    );
    await failing;

    expect(controller.state.status, FeedStatus.appendFailed);
    expect(controller.state.items, hasLength(1));
    expect(controller.state.canAppend, isTrue);

    final retry = controller.loadMore();
    expect(repository.calls.last.cursor, 'c1');
    repository.pending[2].complete(
      FanartPage(items: [_item('b')], snapshotId: 's1'),
    );
    await retry;
    expect(controller.state.items, hasLength(2));
  });

  test(
    '409 during append drops the cursor and reloads the first page',
    () async {
      final loading = controller.loadInitial();
      repository.pending.first.complete(
        FanartPage(items: [_item('a')], snapshotId: 's1', nextCursor: 'c1'),
      );
      await loading;

      final append = controller.loadMore();
      repository.pending[1].completeError(
        const ApiFailure(
          ApiFailureKind.datasetChanged,
          code: 'FANART_SNAPSHOT_CHANGED',
        ),
      );
      // Items stay on screen while the replacement first page is in flight.
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.items, hasLength(1));
      expect(repository.calls.last.cursor, isNull);

      repository.pending[2].complete(
        FanartPage(items: [_item('fresh')], snapshotId: 's2'),
      );
      await append;

      expect(controller.state.items.map((i) => i.identity.value), ['fresh']);
      expect(controller.state.status, FeedStatus.endOfList);
    },
  );

  test(
    'a snapshot change detected without a 409 also restarts the list',
    () async {
      final loading = controller.loadInitial();
      repository.pending.first.complete(
        FanartPage(items: [_item('a')], snapshotId: 's1', nextCursor: 'c1'),
      );
      await loading;

      final append = controller.loadMore();
      repository.pending[1].complete(
        FanartPage(items: [_item('mixed')], snapshotId: 's2', nextCursor: 'c2'),
      );
      await Future<void>.delayed(Duration.zero);
      repository.pending[2].complete(
        FanartPage(items: [_item('fresh')], snapshotId: 's2'),
      );
      await append;

      // The page from the newer dataset is discarded rather than appended.
      expect(controller.state.items.map((i) => i.identity.value), ['fresh']);
    },
  );

  test(
    'refresh keeps current items visible until the new page arrives',
    () async {
      final loading = controller.loadInitial();
      repository.pending.first.complete(
        FanartPage(items: [_item('a')], snapshotId: 's1', nextCursor: 'c1'),
      );
      await loading;

      final refreshing = controller.refresh();
      expect(controller.state.status, FeedStatus.loadingFirstPage);
      expect(controller.state.items, hasLength(1));
      repository.pending.last.complete(
        FanartPage(items: [_item('b')], snapshotId: 's1'),
      );
      await refreshing;
      expect(controller.state.items.map((i) => i.identity.value), ['b']);
    },
  );

  test('an empty first page is a real empty state, not a failure', () async {
    final loading = controller.loadInitial();
    repository.pending.first.complete(
      const FanartPage(items: [], snapshotId: 's1', total: 0),
    );
    await loading;

    expect(controller.state.isEmptyResult, isTrue);
    expect(controller.state.failure, isNull);
    expect(controller.state.status, FeedStatus.endOfList);
  });

  test('first page failure surfaces a retryable error with no items', () async {
    final loading = controller.loadInitial();
    repository.pending.first.completeError(
      const ApiFailure(ApiFailureKind.offline),
    );
    await loading;

    expect(controller.state.status, FeedStatus.failed);
    expect(controller.state.failure?.kind, ApiFailureKind.offline);
    expect(controller.state.isEmptyResult, isFalse);
  });

  test('dispose cancels the in-flight request instead of emitting', () async {
    final loading = controller.loadInitial();
    controller.dispose();
    await loading;
    expect(repository.pending.first.isCompleted, isTrue);

    // Re-created for tearDown, which disposes the field.
    controller = FanartFeedController(repository);
  });
}
