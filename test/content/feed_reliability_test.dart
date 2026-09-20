import 'dart:async';

import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/content/application/community_feed_controller.dart';
import 'package:asasfans_next/features/content/application/dynamic_feed_controller.dart';
import 'package:asasfans_next/features/content/application/fanart_feed_controller.dart';
import 'package:asasfans_next/features/content/domain/community_video_repository.dart';
import 'package:asasfans_next/features/content/domain/dynamic_repository.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

ContentIdentity _identity(String value) =>
    ContentIdentity(source: ContentSource.bilibiliDynamic, value: value);

class _Page {
  const _Page(this.ids, {this.next, this.number});
  final List<String> ids;
  final String? next;
  final int? number;
}

/// Intentionally ignores cancellation to test defensive generation handling.
class _Repository
    implements FanartRepository, DynamicRepository, CommunityVideoRepository {
  final pending = <Completer<_Page>>[];
  final continuations = <Object?>[];
  final handles = <RequestCancellation?>[];

  Future<_Page> _request(
    Object? continuation,
    RequestCancellation? cancellation,
  ) {
    continuations.add(continuation);
    handles.add(cancellation);
    final result = Completer<_Page>();
    pending.add(result);
    return result.future;
  }

  @override
  Future<FanartPage> page({
    FanartQuery query = const FanartQuery(),
    String? cursor,
    RequestCancellation? cancellation,
  }) async {
    final page = await _request(cursor, cancellation);
    return FanartPage(
      items: [
        for (final id in page.ids)
          FanartItem(
            identity: _identity(id),
            text: id,
            authorName: '',
            authorUid: '',
            images: const [],
            kind: FanartKind.fanart,
            contentType: FanartContentType.text,
            category: FanartCategory.normal,
            characterTags: const [],
          ),
      ],
      snapshotId: 'source-snapshot',
      nextCursor: page.next,
    );
  }

  @override
  Future<DynamicPage> search({
    DynamicQuery query = const DynamicQuery(),
    String? cursor,
    RequestCancellation? cancellation,
  }) async {
    final page = await _request(cursor, cancellation);
    return DynamicPage(
      items: [
        for (final id in page.ids)
          DynamicPost(
            identity: _identity(id),
            member: const DynamicMember(id: 'uid:1', name: '嘉然'),
            type: DynamicType.text,
            text: id,
            images: const [],
          ),
      ],
      nextCursor: page.next,
    );
  }

  @override
  Future<CommunityVideoPage> videos({
    CommunityVideoQuery query = const CommunityVideoQuery(),
    int page = 1,
    RequestCancellation? cancellation,
  }) async {
    final result = await _request(page, cancellation);
    return CommunityVideoPage(
      videos: [
        for (final id in result.ids)
          CommunityVideo(
            identity: _identity(id),
            title: id,
            creatorName: '',
            creatorId: '1',
          ),
      ],
      page: result.number ?? page,
      hasMore: result.next != null,
    );
  }

  @override
  Future<FanartItem?> random({
    FanartQuery query = const FanartQuery(),
    RequestCancellation? cancellation,
  }) async => null;
  @override
  Future<List<DynamicMember>> members() async => [];
  @override
  Future<List<DynamicPost>> onThisDay({
    String? monthDay,
    OnThisDaySort sort = OnThisDaySort.hot,
    int limit = 8,
  }) async => [];
}

class _Harness {
  _Harness(String kind, _Repository repository, DateTime Function() clock) {
    switch (kind) {
      case 'fanart':
        final c = FanartFeedController(repository, clock: clock);
        notifier = c;
        initial = c.loadInitial;
        refresh = c.refresh;
        more = c.loadMore;
        status = () => c.state.status;
        ids = () => c.state.items.map((i) => i.identity.value).toList();
      case 'dynamic':
        final c = DynamicFeedController(repository, clock: clock);
        notifier = c;
        initial = c.loadInitial;
        refresh = c.refresh;
        more = c.loadMore;
        status = () => c.state.status;
        ids = () => c.state.items.map((i) => i.identity.value).toList();
      case 'community':
        final c = CommunityFeedController(repository, clock: clock);
        notifier = c;
        initial = c.loadInitial;
        refresh = c.refresh;
        more = c.loadMore;
        status = () => c.state.status;
        ids = () => c.state.videos.map((i) => i.identity.value).toList();
    }
  }
  late ChangeNotifier notifier;
  late Future<void> Function() initial;
  late Future<void> Function() refresh;
  late Future<void> Function({bool automatic}) more;
  late FeedStatus Function() status;
  late List<String> Function() ids;
}

void main() {
  for (final kind in ['fanart', 'dynamic', 'community']) {
    group(kind, () {
      late DateTime now;
      late _Repository repository;
      late _Harness feed;
      setUp(() {
        now = DateTime.utc(2026, 9, 21);
        repository = _Repository();
        feed = _Harness(kind, repository, () => now);
      });
      tearDown(() => feed.notifier.dispose());

      Future<void> seed() async {
        final first = feed.initial();
        repository.pending.last.complete(const _Page(['a', 'a'], next: 'c1'));
        await first;
        expect(feed.ids(), ['a']);
      }

      test(
        'error suspends automatic append but allows explicit retry',
        () async {
          await seed();
          final append = feed.more(automatic: true);
          repository.pending.last.completeError(
            const ApiFailure(ApiFailureKind.timeout),
          );
          await append;
          expect(feed.status(), FeedStatus.appendFailed);
          await feed.more(automatic: true);
          expect(repository.pending, hasLength(2));
          final retry = feed.more();
          repository.pending.last.complete(const _Page(['a', 'b']));
          await retry;
          expect(feed.ids(), ['a', 'b']);
          expect(feed.status(), FeedStatus.endOfList);
        },
      );

      test('429 blocks manual append and refresh until the deadline', () async {
        await seed();
        final append = feed.more();
        repository.pending.last.completeError(
          const ApiFailure(
            ApiFailureKind.rateLimited,
            retryAfter: Duration(seconds: 60),
          ),
        );
        await append;
        await feed.more();
        await feed.refresh();
        expect(repository.pending, hasLength(2));
        expect(feed.ids(), ['a']);
        now = now.add(const Duration(seconds: 60));
        final fresh = feed.refresh();
        repository.pending.last.complete(const _Page(['b']));
        await fresh;
        expect(feed.ids(), ['b']);
      });

      test(
        'empty initial and intermediate pages are not a terminal empty result',
        () async {
          final first = feed.initial();
          repository.pending.last.complete(const _Page([], next: 'c1'));
          await first;
          expect(feed.status(), FeedStatus.ready);
          final append = feed.more();
          repository.pending.last.complete(const _Page([], next: 'c2'));
          await append;
          expect(feed.status(), FeedStatus.ready);
          final next = feed.more();
          repository.pending.last.complete(const _Page(['visible']));
          await next;
          expect(feed.ids(), ['visible']);
          expect(feed.status(), FeedStatus.endOfList);
        },
      );

      test(
        'three consecutive pages without new identities stop the run',
        () async {
          await seed();
          for (var i = 0; i < 3; i++) {
            final append = feed.more();
            repository.pending.last.complete(_Page(['a'], next: 'c${i + 2}'));
            await append;
          }
          expect(feed.ids(), ['a']);
          expect(feed.status(), FeedStatus.stalled);
          await feed.more();
          await feed.more(automatic: true);
          expect(repository.pending, hasLength(4));
        },
      );

      test(
        'refresh failure preserves old content and does not resume its cursor',
        () async {
          await seed();
          final refresh = feed.refresh();
          repository.pending.last.completeError(
            const ApiFailure(ApiFailureKind.offline),
          );
          await refresh;
          expect(feed.ids(), ['a']);
          expect(feed.status(), FeedStatus.failed);
          await feed.more(automatic: true);
          expect(repository.pending, hasLength(2));
        },
      );

      test(
        'refresh cancels append and drops even an uncooperative stale response',
        () async {
          await seed();
          final append = feed.more();
          final oldResponse = repository.pending.last;
          final oldHandle = repository.handles.last!;
          final refresh = feed.refresh();
          expect(oldHandle.isCancelled, isTrue);
          repository.pending.last.complete(const _Page(['fresh']));
          await refresh;
          oldResponse.complete(const _Page(['stale']));
          await append;
          expect(feed.ids(), ['fresh']);
        },
      );

      test(
        'dispose cancels append and never notifies when its response arrives',
        () async {
          await seed();
          final append = feed.more();
          var notifications = 0;
          feed.notifier.addListener(() => notifications++);
          feed.notifier.dispose();
          expect(repository.handles.last!.isCancelled, isTrue);
          repository.pending.last.complete(const _Page(['stale']));
          await append;
          expect(notifications, 0);
          await feed.refresh();
          await feed.more();
          expect(repository.pending, hasLength(2));
        },
      );

      if (kind != 'community') {
        test(
          'a cursor cycle stops without throwing away accepted items',
          () async {
            await seed();
            for (final cursor in ['c2', 'c1']) {
              final append = feed.more();
              repository.pending.last.complete(_Page([cursor], next: cursor));
              await append;
            }
            expect(feed.status(), FeedStatus.stalled);
            expect(feed.ids(), ['a', 'c2', 'c1']);
          },
        );
      } else {
        test(
          'wrong page number is rejected without advancing the counter',
          () async {
            await seed();
            final append = feed.more();
            repository.pending.last.complete(const _Page(['bad'], number: 1));
            await append;
            expect(feed.status(), FeedStatus.appendFailed);
            expect(feed.ids(), ['a']);
            final retry = feed.more();
            expect(repository.continuations.last, 2);
            repository.pending.last.complete(const _Page(['good'], number: 2));
            await retry;
            expect(feed.ids(), ['a', 'good']);
          },
        );
      }
    });
  }
}
