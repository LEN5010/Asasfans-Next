import 'dart:async';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/content/application/fanart_feed_controller.dart';
import 'package:asasfans_next/features/creator/application/creator_controller.dart';
import 'package:asasfans_next/features/creator/domain/creator_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/creator_fixture.dart';

class _Pending implements CreatorRepository {
  final profiles = <(RequestCancellation?, Completer<CreatorProfile>)>[];
  final pages =
      <
        (
          CreatorArchiveQuery,
          int,
          RequestCancellation?,
          Completer<CreatorArchivePage>,
        )
      >[];
  @override
  Future<CreatorProfile> profile(
    String mid, {
    RequestCancellation? cancellation,
  }) {
    final result = Completer<CreatorProfile>();
    profiles.add((cancellation, result));
    return result.future;
  }

  @override
  Future<CreatorArchivePage> archives(
    CreatorArchiveQuery query, {
    int page = 1,
    RequestCancellation? cancellation,
  }) {
    final result = Completer<CreatorArchivePage>();
    pages.add((query, page, cancellation, result));
    return result.future;
  }
}

CreatorArchivePage _page(
  int id, {
  int page = 1,
  int total = 2,
  bool more = true,
}) => CreatorArchivePage(
  items: [creatorVideo(id)],
  page: page,
  total: total,
  hasMore: more,
);
void main() {
  test(
    'profile and archives succeed/fail independently; old profile survives refresh failure',
    () async {
      final source = _Pending();
      final controller = CreatorController(source, '123');
      addTearDown(controller.dispose);
      final request = controller.refresh();
      source.profiles.last.$2.complete(
        const CreatorProfile(mid: '123', name: '测试'),
      );
      source.pages.last.$4.completeError(
        const ApiFailure(ApiFailureKind.riskControl),
      );
      await request;
      expect(controller.profile?.name, '测试');
      expect(controller.profileFailure, isNull);
      expect(controller.archives.failure?.kind, ApiFailureKind.riskControl);
      final retry = controller.refreshProfile();
      source.profiles.last.$2.completeError(
        const ApiFailure(ApiFailureKind.offline),
      );
      await retry;
      expect(controller.profile?.name, '测试');
      expect(controller.profileFailure?.kind, ApiFailureKind.offline);
      expect(source.pages, hasLength(1));
    },
  );
  test(
    'one append at a time; automatic retry pauses but explicit retry can proceed',
    () async {
      final source = _Pending();
      final controller = CreatorController(source, '123');
      addTearDown(controller.dispose);
      final initial = controller.refreshArchives();
      source.pages.last.$4.complete(_page(1));
      await initial;
      final append = controller.loadMore(automatic: true);
      await controller.loadMore(automatic: true);
      expect(source.pages, hasLength(2));
      source.pages.last.$4.completeError(
        const ApiFailure(ApiFailureKind.offline),
      );
      await append;
      await controller.loadMore(automatic: true);
      expect(source.pages, hasLength(2));
      expect(controller.archives.items, hasLength(1));
      final retry = controller.loadMore();
      source.pages.last.$4.complete(_page(2, page: 2, more: false));
      await retry;
      expect(controller.archives.items, hasLength(2));
      expect(controller.archives.status, FeedStatus.endOfList);
    },
  );
  test(
    'search supersedes and cancels in-flight append; late response is discarded',
    () async {
      final source = _Pending();
      final controller = CreatorController(source, '123');
      addTearDown(controller.dispose);
      final initial = controller.refreshArchives();
      source.pages.last.$4.complete(_page(1));
      await initial;
      final old = controller.loadMore();
      final oldPage = source.pages.last;
      final search = controller.applyQuery(
        controller.archives.query.copyWith(keyword: '新'),
      );
      expect(oldPage.$3?.isCancelled, isTrue);
      source.pages.last.$4.complete(_page(3, more: false, total: 1));
      await search;
      oldPage.$4.complete(_page(2, page: 2, more: false));
      await old;
      expect(controller.archives.query.keyword, '新');
      expect(controller.archives.items.single.title, '投稿 3');
    },
  );
  for (final changed in [true, false]) {
    test(
      'changed total / overlapping page stalls without mixing data: $changed',
      () async {
        final source = _Pending();
        final controller = CreatorController(source, '123');
        addTearDown(controller.dispose);
        final initial = controller.refreshArchives();
        source.pages.last.$4.complete(_page(1));
        await initial;
        final append = controller.loadMore();
        source.pages.last.$4.complete(
          _page(changed ? 2 : 1, page: 2, total: changed ? 3 : 2),
        );
        await append;
        expect(controller.archives.status, FeedStatus.stalled);
        expect(
          controller.archives.failure?.kind,
          ApiFailureKind.datasetChanged,
        );
        expect(controller.archives.items.single.title, '投稿 1');
        await controller.loadMore();
        expect(source.pages, hasLength(2));
      },
    );
  }
  test(
    'dispose cancels both requests and never notifies on late completion',
    () async {
      final source = _Pending();
      final controller = CreatorController(source, '123');
      var updates = 0;
      controller.addListener(() => updates++);
      final refresh = controller.refresh();
      final before = updates;
      controller.dispose();
      expect(source.profiles.single.$1?.isCancelled, isTrue);
      expect(source.pages.single.$3?.isCancelled, isTrue);
      source.profiles.single.$2.complete(
        const CreatorProfile(mid: '123', name: 'late'),
      );
      source.pages.single.$4.complete(_page(1));
      await refresh;
      expect(updates, before);
    },
  );
}
