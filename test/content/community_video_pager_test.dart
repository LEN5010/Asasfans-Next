import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/content/application/community_video_pager.dart';
import 'package:asasfans_next/features/content/domain/community_video_repository.dart';
import 'package:flutter_test/flutter_test.dart';

CommunityVideo _video(String id, int rank, {num? score}) => CommunityVideo(
  identity: ContentIdentity(source: ContentSource.bilibiliVideo, value: id),
  title: id,
  creatorName: '作者',
  creatorId: '1',
  publishedAt: DateTime.utc(2026, 1, 1).add(Duration(seconds: rank)),
  rankScore: score,
);

CommunityVideoPage _page(
  int page,
  List<CommunityVideo> videos, {
  bool more = false,
}) => CommunityVideoPage(videos: videos, page: page, hasMore: more, total: 999);

class _Source implements CommunityVideoRepository {
  _Source(this.script);
  final Map<String, List<Object>> script;
  final calls = <({CommunityVideoQuery query, int page})>[];
  void Function(CommunityVideoQuery)? onFetch;

  @override
  Future<CommunityVideoPage> videos({
    CommunityVideoQuery query = const CommunityVideoQuery(),
    int page = 1,
    RequestCancellation? cancellation,
  }) async {
    calls.add((query: query, page: page));
    onFetch?.call(query);
    final result = script[query.tags.lastOrNull ?? '']![page - 1];
    if (result is! CommunityVideoPage) throw result;
    return result;
  }
}

void main() {
  final now = DateTime.utc(2026, 9, 21, 3);

  test(
    'OR includes single-tag matches, deduplicates overlaps and globally merges pages',
    () async {
      final duplicate = _video('both', 7);
      final source = _Source({
        '切片': [
          _page(1, [_video('a9', 9), duplicate], more: true),
          _page(2, [_video('a5', 5), _video('a3', 3)]),
        ],
        '直播剪辑': [
          _page(1, [_video('b8', 8), duplicate], more: true),
          _page(2, [_video('b6', 6), _video('b4', 4)]),
        ],
      });
      final pager = CommunityVideoPager(
        source,
        query: const CommunityVideoQuery(),
        anyTags: ['切片', '直播剪辑'],
        now: now,
        pageSize: 3,
      );
      final pages = <CommunityVideoPage>[];
      do {
        pages.add(await pager.next());
      } while (pages.last.hasMore);
      expect(pages.expand((p) => p.videos).map((v) => v.identity.value), [
        'a9',
        'b8',
        'both',
        'b6',
        'a5',
        'b4',
        'a3',
      ]);
      expect(pages.map((p) => p.page), [1, 2, 3]);
      expect(pages.every((p) => p.total == null), isTrue);
      expect(source.calls.every((c) => c.query.tags.length == 1), isTrue);
      expect(source.calls.every((c) => c.query.asOf == now), isTrue);
      expect(source.calls, hasLength(4));
    },
  );

  test('source score, not view count or date, orders the hot union', () async {
    final source = _Source({
      '切片': [
        _page(1, [_video('a', 100, score: 10)]),
      ],
      '直播剪辑': [
        _page(1, [_video('b', 1, score: 20)]),
      ],
    });
    final pager = CommunityVideoPager(
      source,
      query: const CommunityVideoQuery(order: CommunityVideoOrder.score),
      anyTags: ['切片', '直播剪辑'],
      now: now,
    );
    expect((await pager.next()).videos.map((v) => v.identity.value), [
      'b',
      'a',
    ]);
  });

  test(
    'empty intermediate source pages do not hide the other tag or fake exhaustion',
    () async {
      final source = _Source({
        '切片': [
          _page(1, [], more: true),
          _page(2, [_video('a', 10)]),
        ],
        '直播剪辑': [_page(1, [])],
      });
      final pager = CommunityVideoPager(
        source,
        query: const CommunityVideoQuery(),
        anyTags: ['切片', '直播剪辑'],
        now: now,
      );
      final page = await pager.next();
      expect(page.videos.single.identity.value, 'a');
      expect(page.hasMore, isFalse);
    },
  );

  test(
    'one failed lane rolls back the output page instead of silently returning a partial channel',
    () async {
      final source = _Source({
        '切片': [
          _page(1, [_video('a3', 3), _video('a1', 1)]),
        ],
        '直播剪辑': [const ApiFailure(ApiFailureKind.offline)],
      });
      final pager = CommunityVideoPager(
        source,
        query: const CommunityVideoQuery(),
        anyTags: ['切片', '直播剪辑'],
        now: now,
        pageSize: 2,
      );
      await expectLater(pager.next(), throwsA(isA<ApiFailure>()));
      source.script['直播剪辑']![0] = _page(1, [_video('b2', 2)]);
      final first = await pager.next();
      expect(first.page, 1);
      expect(first.videos.map((v) => v.identity.value), ['a3', 'b2']);
      expect((await pager.next()).videos.single.identity.value, 'a1');
    },
  );

  test(
    'append rollback retains buffers already committed by the previous page',
    () async {
      final source = _Source({
        '切片': [
          _page(1, [_video('a9', 9), _video('a6', 6)]),
        ],
        '直播剪辑': [
          _page(1, [_video('b8', 8)], more: true),
          const ApiFailure(ApiFailureKind.timeout),
        ],
      });
      final pager = CommunityVideoPager(
        source,
        query: const CommunityVideoQuery(),
        anyTags: ['切片', '直播剪辑'],
        now: now,
        pageSize: 2,
      );
      expect((await pager.next()).videos.map((v) => v.identity.value), [
        'a9',
        'b8',
      ]);
      await expectLater(pager.next(), throwsA(isA<ApiFailure>()));
      source.script['直播剪辑']![1] = _page(2, [_video('b7', 7)]);
      final retried = await pager.next();
      expect(retried.page, 2);
      expect(retried.videos.map((v) => v.identity.value), ['b7', 'a6']);
    },
  );

  test('cancelled merge never commits a partially consumed page', () async {
    final source = _Source({
      '切片': [
        _page(1, [_video('a', 2)]),
      ],
      '直播剪辑': [
        _page(1, [_video('b', 1)]),
      ],
    });
    final cancellation = RequestCancellation();
    source.onFetch = (_) {
      if (source.calls.length == 2) cancellation.cancel();
    };
    final pager = CommunityVideoPager(
      source,
      query: const CommunityVideoQuery(),
      anyTags: ['切片', '直播剪辑'],
      now: now,
    );
    await expectLater(
      pager.next(cancellation: cancellation),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.kind,
          'kind',
          ApiFailureKind.cancelled,
        ),
      ),
    );
    source.onFetch = null;
    final retry = await pager.next();
    expect(retry.page, 1);
    expect(retry.videos.map((v) => v.identity.value), ['a', 'b']);
  });

  test('frozen window and shared filters apply to every lane', () async {
    final source = _Source({
      '切片': [_page(1, [])],
      '直播剪辑': [_page(1, [])],
    });
    final pager = CommunityVideoPager(
      source,
      query: const CommunityVideoQuery(
        tags: ['嘉然'],
        creatorId: '1',
        withinDays: 7,
      ),
      anyTags: ['切片', '直播剪辑', '切片'],
      now: now,
    );
    await pager.next();
    expect(source.calls, hasLength(2));
    for (final call in source.calls) {
      expect(call.query.tags, contains('嘉然'));
      expect(call.query.creatorId, '1');
      expect(call.query.withinDays, 7);
      expect(call.query.asOf, now);
    }
  });

  test(
    'single source path keeps server pagination without requiring unused sort keys',
    () async {
      final source = _Source({
        '': [
          _page(1, [], more: true),
          _page(2, [_video('latest', 1)]),
        ],
      });
      final pager = CommunityVideoPager(
        source,
        query: const CommunityVideoQuery(),
        now: now,
      );
      expect((await pager.next()).hasMore, isTrue);
      expect((await pager.next()).videos.single.identity.value, 'latest');
      expect(source.calls.map((c) => c.page), [1, 2]);
    },
  );

  test('endless empty source pages stop with a bounded error', () async {
    final source = _Source({
      '切片': [for (var page = 1; page <= 3; page++) _page(page, [], more: true)],
      '直播剪辑': [_page(1, [])],
    });
    final pager = CommunityVideoPager(
      source,
      query: const CommunityVideoQuery(),
      anyTags: ['切片', '直播剪辑'],
      now: now,
    );
    await expectLater(
      pager.next(),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.kind,
          'kind',
          ApiFailureKind.paginationStalled,
        ),
      ),
    );
    expect(source.calls.length, lessThanOrEqualTo(4));
  });

  test(
    'an increasing source rank rejects an unstable page rather than corrupting global ordering',
    () async {
      final source = _Source({
        '切片': [
          _page(1, [_video('a3', 3)], more: true),
          _page(2, [_video('inserted', 4)]),
        ],
        '直播剪辑': [
          _page(1, [_video('b2', 2)]),
        ],
      });
      final pager = CommunityVideoPager(
        source,
        query: const CommunityVideoQuery(),
        anyTags: ['切片', '直播剪辑'],
        now: now,
        pageSize: 1,
      );
      await pager.next();
      await expectLater(
        pager.next(),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.datasetChanged,
          ),
        ),
      );
    },
  );

  test('unknown ranking values do not silently become zero', () async {
    final source = _Source({
      '切片': [
        _page(1, [_video('missingScore', 10)]),
      ],
      '直播剪辑': [_page(1, [])],
    });
    final pager = CommunityVideoPager(
      source,
      query: const CommunityVideoQuery(order: CommunityVideoOrder.score),
      anyTags: ['切片', '直播剪辑'],
      now: now,
    );
    await expectLater(
      pager.next(),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.kind,
          'kind',
          ApiFailureKind.invalidResponse,
        ),
      ),
    );
  });
}
