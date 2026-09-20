import 'package:asasfans_next/core/bilibili/bili_media_policy.dart';
import 'package:asasfans_next/core/bilibili/bili_media_transport.dart';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/account_fixture.dart';
import '../helpers/video_comment_fixture.dart';

void main() {
  test('CDN cookie scope is stricter than media destination scope', () {
    for (final host in [
      'v.bilivideo.com',
      'v.bilivideo.cn',
      'v.bilibili.com',
    ]) {
      expect(
        BiliMediaPolicy.headers(
          Uri.https(host, '/video'),
          fixtureBvid,
          accountCredentials(),
        )['Cookie'],
        contains('fixture-session'),
      );
    }
    for (final host in ['v.akamaized.net', 'v.acgvideo.com', 'v.hdslb.com']) {
      final headers = BiliMediaPolicy.headers(
        Uri.https(host, '/video'),
        fixtureBvid,
        accountCredentials(),
      );
      expect(headers.containsKey('Cookie'), isFalse);
      expect(headers.containsKey('Authorization'), isFalse);
    }
    for (final url in [
      'http://v.bilivideo.com/video',
      'https://v.bilivideo.com:444/video',
      'https://u@v.bilivideo.com/video',
      'https://v.bilivideo.com.evil.test/video',
      'https://127.0.0.1/video',
      'https://v.bilivideo.com/video#secret',
    ]) {
      expect(BiliMediaPolicy.allowed(Uri.parse(url)), isFalse);
    }
    expect(
      BiliMediaPolicy.fromApi('http://v.bilivideo.com/video').scheme,
      'https',
    );
    expect(
      BiliMediaPolicy.headers(
        Uri.https('v.bilivideo.com', '/video'),
        fixtureBvid,
        null,
      ).containsKey('Cookie'),
      isFalse,
    );
  });
  test(
    'single closed/open/suffix byte ranges are canonical; injection/multipart/invalid numbers fail',
    () {
      for (final range in ['bytes=0-', 'bytes=0-99', 'bytes=-100']) {
        expect(MediaByteRange.parse(range)?.wire, range);
      }
      for (final range in [
        'bytes=-',
        'bytes=-0',
        'bytes=9-1',
        'bytes=0-1,5-6',
        'bytes=0-\r\nCookie: x',
        'bytes=9007199254740992-',
      ]) {
        expect(() => MediaByteRange.parse(range), throwsA(isA<ApiFailure>()));
      }
    },
  );
}
