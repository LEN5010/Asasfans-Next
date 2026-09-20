import 'package:asasfans_next/core/bilibili/bili_metadata_client.dart';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/comments/data/bili_comment_repository.dart';
import 'package:asasfans_next/features/comments/domain/comments.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/video_comment_fixture.dart';

void main() {
  const query = CommentQuery(oid: fixtureAid);
  test('a pin-only terminal page is not an invalid empty response', () {
    final value = BiliCommentRepository.decode(
      {
        ...commentPagePayload(total: 1, length: 0),
        'upper': {'top': commentPayload(1)},
      },
      query,
      1,
    );
    expect(value.items, isEmpty);
    expect(value.pinned, hasLength(1));
    expect(value.hasMore, isFalse);
  });
  test(
    'root and reply endpoints use AID/type 1, documented sort and no write params',
    () async {
      final gateway = FixtureReadGateway();
      final repository = BiliCommentRepository(gateway);
      final first = await repository.page(query);
      expect(first.hasMore, isTrue);
      final second = await repository.page(query, page: 2);
      expect(second.items, hasLength(1));
      expect(second.hasMore, isFalse);
      expect(gateway.calls.first.parameters, {
        'type': '1',
        'oid': fixtureAid,
        'ps': '20',
        'pn': '1',
        'sort': '1',
        'nohot': '1',
      });
      await repository.page(const CommentQuery(oid: fixtureAid, root: '100'));
      expect(gateway.calls.last.endpoint, BiliReadEndpoint.commentReplies);
      expect(gateway.calls.last.parameters, {
        'type': '1',
        'oid': fixtureAid,
        'ps': '20',
        'pn': '1',
        'root': '100',
      });
      await expectLater(
        repository.page(const CommentQuery(oid: fixtureBvid)),
        throwsA(isA<ApiFailure>()),
      );
      expect(gateway.calls, hasLength(3));
    },
  );
  test(
    'pinned comment, one-level preview, images and long rpid are preserved without executing links',
    () {
      final raw = commentPayload(9007199254740995, replies: 1);
      raw['replies'] = [
        commentPayload(9007199254740996, root: '9007199254740995'),
      ];
      raw['content'] = {
        'message': '[微笑] <b>text</b> https://example.test',
        'pictures': [
          {'img_src': '//i0.hdslb.com/bfs/example.png'},
          {'img_src': 'javascript:bad'},
        ],
      };
      final decoded = BiliCommentRepository.decode(
        {
          ...commentPagePayload(total: 1),
          'replies': [raw],
          'upper': {'top': raw},
        },
        query,
        1,
      );
      expect(decoded.items.single.id, '9007199254740995');
      expect(decoded.pinned.single.id, decoded.items.single.id);
      expect(decoded.items.single.previews.single.root, '9007199254740995');
      expect(decoded.items.single.pictures, hasLength(1));
      expect(decoded.items.single.pictures.single.scheme, 'https');
      expect(decoded.items.single.message, contains('<b>text</b>'));
    },
  );
  test(
    'closed comments are explicit; login and risk never turn into empty comments',
    () async {
      final gateway = FixtureReadGateway();
      final repository = BiliCommentRepository(gateway);
      gateway.respond = (_, _, _) async =>
          throw const ApiFailure(ApiFailureKind.forbidden, code: '12002');
      expect((await repository.page(query)).closed, isTrue);
      for (final kind in [
        ApiFailureKind.loginRequired,
        ApiFailureKind.riskControl,
        ApiFailureKind.offline,
      ]) {
        gateway.respond = (_, _, _) async => throw ApiFailure(kind);
        await expectLater(
          repository.page(query),
          throwsA(isA<ApiFailure>().having((e) => e.kind, 'kind', kind)),
        );
      }
      gateway.respond = (_, _, _) async => commentPagePayload(total: 0);
      expect((await repository.page(query)).closed, isFalse);
    },
  );
  test(
    'cross-video roots, identities, reply roots and inconsistent page fields reject atomically',
    () {
      for (final row in [
        {...commentPayload(1), 'oid': '99'},
        {...commentPayload(1), 'type': 17},
        {...commentPayload(1), 'rpid_str': '2'},
        {...commentPayload(1), 'root_str': '99'},
        {
          ...commentPayload(1),
          'member': {'mid': '999', 'uname': 'wrong'},
        },
        {
          ...commentPayload(1),
          'replies': [commentPayload(2, root: '88')],
        },
      ]) {
        expect(
          () => BiliCommentRepository.decode(
            {
              ...commentPagePayload(total: 1),
              'replies': [row],
            },
            query,
            1,
          ),
          throwsA(isA<ApiFailure>()),
        );
      }
      expect(
        () =>
            BiliCommentRepository.decode(commentPagePayload(page: 2), query, 1),
        throwsA(isA<ApiFailure>()),
      );
      expect(
        () => BiliCommentRepository.decode(
          commentPagePayload(total: 21, length: 0),
          query,
          1,
        ),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.paginationStalled,
          ),
        ),
      );
      expect(
        () => BiliCommentRepository.decode(
          {...commentPagePayload(root: '101'), 'root': commentPayload(102)},
          const CommentQuery(oid: fixtureAid, root: '101'),
          1,
        ),
        throwsA(isA<ApiFailure>()),
      );
    },
  );
}
