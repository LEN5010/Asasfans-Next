import 'dart:typed_data';

import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/content/data/community_video_source.dart';
import 'package:asasfans_next/features/content/domain/community_video_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString(
      '',
      429,
      headers: {
        'retry-after': ['60'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'tags distinguish absent metadata from known empty and parse historical quoted values',
    () {
      CommunityVideoPage decode(Map<String, Object?> row) =>
          CommunityVideoSource.decodePage({
            'data': {
              'page': 1,
              'numResults': 1,
              'result': [row],
            },
          }, requestedPage: 1);
      expect(decode({'bvid': 'BV1'}).videos.single.tags, isNull);
      expect(decode({'bvid': 'BV1', 'tag': ''}).videos.single.tags, isEmpty);
      expect(
        decode({'bvid': 'BV1', 'tag': "'嘉然', '切片', '嘉然'"}).videos.single.tags,
        ['嘉然', '切片'],
      );
    },
  );

  test(
    'a frozen window does not drift as later source pages are requested',
    () {
      final anchor = DateTime.utc(2026, 9, 21, 3);
      final query = CommunityVideoQuery(withinDays: 7, asOf: anchor);
      final first = CommunityVideoSource.buildQuery(
        query,
        page: 1,
        now: anchor,
      );
      final later = CommunityVideoSource.buildQuery(
        query,
        page: 2,
        now: anchor.add(const Duration(hours: 2)),
      );
      expect(first['q'], later['q']);
      final unrestricted = CommunityVideoSource.buildQuery(
        CommunityVideoQuery(asOf: anchor),
        page: 1,
        now: anchor,
      );
      expect(
        unrestricted['q'],
        'pubdate.0+${anchor.millisecondsSinceEpoch ~/ 1000}.BETWEEN',
      );
    },
  );

  test(
    'legacy numeric strings preserve duration and ranking without inventing unknown values',
    () {
      final result = CommunityVideoSource.decodePage({
        'data': {
          'page': '1',
          'numResults': '2',
          'result': [
            {
              'bvid': 'BV1',
              'duration': '266',
              'score': '988',
              'pubdate': '1642340453',
            },
            {
              'bvid': 'BV2',
              'duration': 'unknown',
              'score': 'NaN',
              'pubdate': 1e100,
            },
          ],
        },
      }, requestedPage: 1);
      expect(result.videos.first.duration, const Duration(seconds: 266));
      expect(result.videos.first.rankScore, 988);
      expect(
        result.videos.first.publishedAt,
        DateTime.fromMillisecondsSinceEpoch(1642340453000, isUtc: true),
      );
      expect(result.videos.last.duration, isNull);
      expect(result.videos.last.rankScore, isNull);
      expect(result.videos.last.publishedAt, isNull);
    },
  );
  test(
    'tag set equality is symmetric and hash independent of order or duplicates',
    () {
      const a = CommunityVideoQuery(tags: ['切片', '直播剪辑']);
      const b = CommunityVideoQuery(tags: ['直播剪辑', '切片', '切片']);
      expect(a, b);
      expect(b, a);
      expect(a.hashCode, b.hashCode);
      expect({a, b}, hasLength(1));
      expect(a, isNot(const CommunityVideoQuery(tags: ['切片', '切片'])));
    },
  );

  test('creator ids and tags cannot inject filter operators', () {
    for (final id in ['+1', ' 1', '1.OR', '-1', '0']) {
      expect(CommunityVideoQuery(creatorId: id).isServerAcceptable, isFalse);
    }
    for (final tag in ['切片+直播', 'tag.OR', 'tag~mid']) {
      expect(CommunityVideoQuery(tags: [tag]).isServerAcceptable, isFalse);
    }
    expect(
      const CommunityVideoQuery(creatorId: '703007996').isServerAcceptable,
      isTrue,
    );
  });

  test('verified single-tag query keeps uploader, time window and page', () {
    final now = DateTime.utc(2026, 9, 21);
    final query = CommunityVideoSource.buildQuery(
      const CommunityVideoQuery(tags: ['切片'], creatorId: '1', withinDays: 7),
      page: 2,
      now: now,
    );
    expect(
      query['q'],
      'tag.切片.AND~mid.1.OR~pubdate.'
      '${now.subtract(const Duration(days: 7)).millisecondsSinceEpoch ~/ 1000}+'
      '${now.millisecondsSinceEpoch ~/ 1000}.BETWEEN',
    );
    expect(query['page'], '2');
    expect(query['order'], 'pubdate');
  });

  test(
    'decode rejects wrong pages and deduplicates stable video identities',
    () {
      final json = {
        'data': {
          'page': 2,
          'numResults': 41,
          'result': [
            {
              'bvid': 'BVfixture',
              'title': 'title',
              'pic': '//i0.hdslb.com/cover.jpg',
              'view': -1,
            },
            {'bvid': 'BVfixture', 'title': 'duplicate'},
          ],
        },
      };
      final result = CommunityVideoSource.decodePage(json, requestedPage: 2);
      expect(result.videos, hasLength(1));
      expect(result.videos.single.coverUrl?.scheme, 'https');
      expect(result.videos.single.viewCount, isNull);
      expect(result.hasMore, isTrue);
      expect(
        () => CommunityVideoSource.decodePage(json, requestedPage: 1),
        throwsA(isA<ApiFailure>()),
      );
    },
  );

  test(
    'rate limit is shared across different queries at the source boundary',
    () async {
      var now = DateTime.utc(2026, 9, 21);
      final adapter = _Adapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final source = CommunityVideoSource(
        dio,
        endpoint: Uri.parse('https://example.test/videos'),
        clock: () => now,
      );
      await expectLater(source.videos(), throwsA(isA<ApiFailure>()));
      now = now.add(const Duration(seconds: 30));
      await expectLater(
        source.videos(query: const CommunityVideoQuery(creatorId: '1')),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.retryAfter,
            'remaining',
            const Duration(seconds: 30),
          ),
        ),
      );
      expect(adapter.calls, 1);
    },
  );
}
