import 'package:asasfans_next/core/bilibili/bili_metadata_client.dart';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/player/data/bili_playback_repository.dart';
import 'package:asasfans_next/features/player/data/dash_manifest.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/playback_fixture.dart';
import '../helpers/video_comment_fixture.dart';

void main() {
  test(
    'acquisition uses WBI endpoint and real CID; no preview-bypass or CSRF params',
    () async {
      final gateway = FixtureReadGateway()
        ..respond = (_, _, _) async => dashPayload();
      final repository = BiliPlaybackRepository(
        gateway,
        clock: () => playbackNow,
      );
      final value = await repository.acquire(playbackRequest);
      expect(gateway.calls.single.endpoint, BiliReadEndpoint.playUrl);
      expect(gateway.calls.single.parameters, {
        'bvid': fixtureBvid,
        'cid': '801',
        'qn': '80',
        'fnval': '4048',
        'fnver': '0',
        'fourk': '1',
        'otype': 'json',
        'platform': 'pc',
        'gaia_source': 'view-card',
      });
      expect(value.availableQualities, [80, 32]);
      expect(value.availableQualities, isNot(contains(120)));
      expect(value.videoFor(80)?.codecId, 7);
      expect(value.videoFor(120)?.id, 80);
      expect(value.videoFor(16)?.id, 32);
      expect(value.defaultAudio?.id, 30280);
      expect(value.refreshAfter, playbackNow.add(const Duration(minutes: 110)));
      expect(value.toString(), isNot(contains('fixture-private')));
      expect(value.video.first.toString(), isNot(contains('token=')));
    },
  );
  test(
    'silent DASH is valid; manifest has only loopback resources and real byte ranges',
    () {
      final source = BiliPlaybackRepository.decode(
        dashPayload(silent: true),
        playbackRequest,
        playbackNow,
      );
      var count = 0;
      final xml = DashManifest.build(
        source,
        quality: 80,
        localResource: (_) =>
            Uri.parse('http://127.0.0.1:51234/session/track-${count++}'),
      );
      expect(source.defaultAudio, isNull);
      expect(xml, contains('indexRange="100-199"'));
      expect(xml, contains('range="0-99"'));
      expect(xml, isNot(contains('fixture-private')));
      expect(xml, isNot(contains('bilivideo.com')));
      expect(xml, isNot(contains('audio/mp4')));
      expect(xml, contains('avc1.640028'));
      expect(count, 1);
      expect(
        () => DashManifest.build(
          source,
          quality: 80,
          localResource: (_) =>
              Uri.parse('https://primary.bilivideo.com/remote'),
        ),
        throwsA(isA<ApiFailure>()),
      );
    },
  );
  test(
    'MP4 preserves every segment, order and actual returned quality',
    () async {
      final gateway = FixtureReadGateway()
        ..respond = (_, _, _) async => mp4Payload(segments: 2);
      final repository = BiliPlaybackRepository(
        gateway,
        clock: () => playbackNow,
      );
      final source = await repository.acquire(playbackRequest.asMp4());
      expect(gateway.calls.single.parameters['fnval'], '1');
      expect(source.mp4, hasLength(2));
      expect(source.duration, const Duration(minutes: 1));
      expect(source.returnedQuality, 32);
      expect(source.availableQualities, [32]);
      expect(source.isDash, isFalse);
    },
  );
  test('business failures never automatically retry another format', () async {
    final gateway = FixtureReadGateway()
      ..respond = (_, _, _) async =>
          throw const ApiFailure(ApiFailureKind.riskControl);
    await expectLater(
      BiliPlaybackRepository(gateway).acquire(playbackRequest),
      throwsA(isA<ApiFailure>()),
    );
    expect(gateway.calls, hasLength(1));
    expect(
      () => BiliPlaybackRepository.decode(
        {...mp4Payload(), 'format': 'flv'},
        playbackRequest,
        playbackNow,
      ),
      throwsA(isA<ApiFailure>()),
    );
  });
  test(
    'foreign identity, malformed ranges, zero duration and invalid track shape fail closed',
    () {
      for (final payload in [
        {...dashPayload(), 'cid': '999'},
        {...dashPayload(), 'timelength': 0},
        {
          ...dashPayload(),
          'dash': {
            'video': [
              {
                ...dashTrack(),
                'segment_base': {
                  'initialization': '0-199',
                  'index_range': '100-150',
                },
              },
            ],
          },
        },
        {
          ...dashPayload(),
          'dash': {
            'video': [
              {...dashTrack(), 'width': -1},
            ],
          },
        },
        {
          ...dashPayload(),
          'dash': {
            'video': [
              {...dashTrack(), 'codecs': 'x" injected="1'},
            ],
          },
        },
      ]) {
        expect(
          () => BiliPlaybackRepository.decode(
            payload,
            playbackRequest,
            playbackNow,
          ),
          throwsA(isA<ApiFailure>()),
        );
      }
    },
  );
  test(
    'unsafe/expired primary can use a safe backup; no candidate means no source',
    () {
      Map<String, Object?> data(Object? url, Object? backup) => {
        ...mp4Payload(),
        'durl': [
          {'order': 1, 'length': 30000, 'url': url, 'backup_url': backup},
        ],
      };
      final future = 'https://mirror.akamaized.net/video?token=fixture';
      final source = BiliPlaybackRepository.decode(
        data('http://127.0.0.1/private', [future]),
        playbackRequest,
        playbackNow,
      );
      expect(
        source.mp4.single.resource.locations.single.host,
        'mirror.akamaized.net',
      );
      final expired =
          'https://primary.bilivideo.com/video?deadline=${playbackNow.millisecondsSinceEpoch ~/ 1000 - 1}';
      expect(
        () => BiliPlaybackRepository.decode(
          data(expired, []),
          playbackRequest,
          playbackNow,
        ),
        throwsA(isA<ApiFailure>()),
      );
      expect(
        () => BiliPlaybackRepository.decode(
          data('https://primary.bilivideo.com/video?deadline=%FF', []),
          playbackRequest,
          playbackNow,
        ),
        throwsA(isA<ApiFailure>()),
      );
    },
  );
}
