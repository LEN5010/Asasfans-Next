import 'package:asasfans_next/core/bilibili/bili_metadata_client.dart';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/video/data/bili_video_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/video_comment_fixture.dart';

void main() {
  test(
    'fixed view endpoint, exact BVID/AID/CID identity and unknown metrics',
    () async {
      final gateway = FixtureReadGateway();
      final repository = BiliVideoRepository(gateway);
      final value = await repository.detail(fixtureBvid);
      expect(gateway.calls.single.endpoint, BiliReadEndpoint.video);
      expect(gateway.calls.single.parameters, {'bvid': fixtureBvid});
      expect(value.aid, fixtureAid);
      expect(value.parts.map((p) => p.cid), ['801', '802']);
      expect(value.partUrl(value.parts.last).queryParameters, {'p': '2'});
      expect(value.favoriteCount, isNull);
      expect(value.video.tags, isNull);
      await expectLater(
        repository.detail('invalid'),
        throwsA(isA<ApiFailure>()),
      );
      expect(gateway.calls, hasLength(1));
    },
  );
  test(
    'mismatched identifiers, duplicate CID, page holes and unsafe number types fail',
    () {
      final variants = <Map<String, Object?>>[
        {...videoPayload(), 'bvid': 'BV1yy411c7mD'},
        {...videoPayload(), 'aid': 9007199254740992.0},
        {...videoPayload(), 'cid': '999'},
        {...videoPayload(), 'videos': 3},
        {...videoPayload(), 'pages': []},
        {
          ...videoPayload(),
          'pages': [
            {'cid': '801', 'page': 1, 'part': 'one'},
            {'cid': '801', 'page': 2, 'part': 'two'},
          ],
        },
        {
          ...videoPayload(),
          'pages': [
            {'cid': '801', 'page': 1, 'part': 'one'},
            {'cid': '802', 'page': 3, 'part': 'two'},
          ],
        },
      ];
      for (final raw in variants) {
        expect(
          () => BiliVideoRepository.decode(raw, fixtureBvid),
          throwsA(isA<ApiFailure>()),
        );
      }
    },
  );
  test('interactive and PGC metadata do not become an acquired stream', () {
    final raw = {
      ...videoPayload(),
      'rights': {'is_stein_gate': 1},
      'redirect_url': 'https://www.bilibili.com/bangumi/play/ep123',
    };
    final value = BiliVideoRepository.decode(raw, fixtureBvid);
    expect(value.interactive, isTrue);
    expect(value.redirectUrl?.host, 'www.bilibili.com');
    expect(
      BiliVideoRepository.decode({
        ...raw,
        'redirect_url': 'https://evil.test/',
      }, fixtureBvid).redirectUrl,
      isNull,
    );
  });
}
