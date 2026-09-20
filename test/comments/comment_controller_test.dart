import 'dart:async';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/content/application/fanart_feed_controller.dart'
    show FeedStatus;
import 'package:asasfans_next/features/comments/application/comment_controller.dart';
import 'package:asasfans_next/features/comments/domain/comments.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/video_comment_fixture.dart';

void main() {
  late OfflineCommentRepository repository;
  late CommentController controller;
  setUp(() {
    repository = OfflineCommentRepository();
    controller = CommentController(
      repository,
      const CommentQuery(oid: fixtureAid),
    );
  });
  tearDown(() => controller.dispose());
  test(
    'pinned duplicates render once but never consume regular page positions',
    () async {
      repository.respond = (_, page, _) async => CommentPage(
        page: page,
        total: 21,
        items: page == 1
            ? List.generate(20, (i) => commentFixture(i + 1))
            : [commentFixture(21)],
        pinned: page == 1 ? [commentFixture(1)] : [],
      );
      await controller.refresh();
      expect(controller.visible, hasLength(20));
      await controller.loadMore();
      expect(controller.visible, hasLength(21));
      expect(controller.visible.first.id, '1');
      expect(controller.status, FeedStatus.endOfList);
    },
  );
  test(
    'append error pauses automatic paging and retry uses the same page',
    () async {
      await controller.refresh();
      repository.respond = (_, _, _) async => throw const ApiFailure(
        ApiFailureKind.rateLimited,
        retryAfter: Duration(seconds: 30),
      );
      await controller.loadMore();
      expect(controller.status, FeedStatus.appendFailed);
      expect(controller.items, hasLength(20));
      await controller.loadMore(automatic: true);
      expect(repository.calls, hasLength(2));
      repository.respond = null;
      await controller.loadMore();
      expect(repository.calls.map((c) => c.page), [1, 2, 2]);
      expect(controller.items, hasLength(21));
    },
  );
  test(
    'page-number count changes or regular overlap require refresh, not silent skipping',
    () async {
      await controller.refresh();
      repository.respond = (_, page, _) async =>
          CommentPage(page: page, total: 22, items: [commentFixture(999)]);
      await controller.loadMore();
      expect(controller.status, FeedStatus.stalled);
      expect(controller.page, 1);
      expect(controller.items, hasLength(20));
      repository.respond = null;
      await controller.refresh();
      repository.respond = (_, page, _) async =>
          CommentPage(page: page, total: 21, items: [commentFixture(100)]);
      await controller.loadMore();
      expect(controller.failure?.kind, ApiFailureKind.datasetChanged);
      expect(controller.items, hasLength(20));
    },
  );
  test(
    'new sort cancels old response, and an old failure cannot affect the new list',
    () async {
      final pending = Completer<CommentPage>();
      RequestCancellation? token;
      repository.respond = (_, _, cancel) {
        token = cancel;
        return pending.future;
      };
      final first = controller.refresh();
      repository.respond = null;
      await controller.refresh(order: CommentOrder.latest);
      expect(token!.isCancelled, isTrue);
      expect(controller.query.order, CommentOrder.latest);
      pending.completeError(const ApiFailure(ApiFailureKind.offline));
      await first;
      expect(controller.failure, isNull);
      expect(controller.items, hasLength(20));
    },
  );
  test(
    'explicit closure removes old visible comments; disposal ignores in-flight data',
    () async {
      await controller.refresh();
      repository.respond = (_, page, _) async =>
          CommentPage(page: page, total: 0, items: [], closed: true);
      await controller.loadMore();
      expect(controller.closed, isTrue);
      expect(controller.visible, isEmpty);
      final pending = Completer<CommentPage>();
      repository.respond = (_, _, _) => pending.future;
      final load = controller.refresh();
      final token = repository.calls.last.cancellation;
      controller.dispose();
      expect(token!.isCancelled, isTrue);
      pending.complete(
        CommentPage(page: 1, total: 1, items: [commentFixture(77)]),
      );
      await load;
      expect(controller.items, isEmpty);
    },
  );
}
