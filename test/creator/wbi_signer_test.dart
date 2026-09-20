import 'package:asasfans_next/core/bilibili/wbi_signer.dart';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/bili_fixture.dart';

void main() {
  test('public reference vector, sorted query and caller immutability', () {
    final parameters = {'foo': '114', 'bar': '514', 'zab': '1919810'};
    final signed = fixtureKeys().sign(
      parameters,
      DateTime.fromMillisecondsSinceEpoch(1702204169000, isUtc: true),
    );
    expect(
      signed,
      'bar=514&foo=114&wts=1702204169&zab=1919810&w_rid=8f6f2b5b3d485fe1886cec6a0be8c5d4',
    );
    expect(parameters, {'foo': '114', 'bar': '514', 'zab': '1919810'});
    expect(fixtureKeys().toString(), 'WbiKeys(redacted)');
  });
  test(
    'sign strips only forbidden value characters and encodes UTF-8 once',
    () {
      final signed = fixtureKeys().sign({
        'keyword': "嘉然 +!'()*&",
      }, DateTime.utc(2026));
      expect(signed, startsWith('keyword=%E5%98%89%E7%84%B6%20%2B%26&wts='));
      expect(WbiKeys.encode({'a': "!'()* +"}), 'a=%21%27%28%29%2A%20%2B');
      for (final reserved in ['wts', 'w_rid']) {
        expect(
          () => fixtureKeys().sign({reserved: '1'}, DateTime.utc(2026)),
          throwsA(isA<ApiFailure>()),
        );
      }
    },
  );
  test('key URLs are parsed, not fetched; malformed key names fail', () {
    for (final url in [
      '',
      'file:///a.png',
      'http://i0.hdslb.com/key.png',
      'https://example.test/short.png',
      'https://user@example.test/${'a' * 32}.png',
    ]) {
      expect(
        () => WbiKeys.fromUrls(url, subKeyUrl),
        throwsA(isA<ApiFailure>()),
      );
    }
  });
}
