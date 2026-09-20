import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:asasfans_next/core/bilibili/bili_metadata_client.dart';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/account/data/bili_auth_client.dart';
import 'package:asasfans_next/features/account/domain/bili_account.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/account_fixture.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final FutureOr<ResponseBody> Function(RequestOptions) respond;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

List<String> _cookies() => [
  for (final entry in accountCredentials().cookies.entries)
    '${entry.key}=${entry.value}; Domain=.bilibili.com; Path=/; Secure; HttpOnly',
];
ResponseBody _json(
  Object? data, {
  int code = 0,
  List<String> cookies = const [],
}) => ResponseBody.fromString(
  jsonEncode({'code': code, 'data': data}),
  200,
  headers: {if (cookies.isNotEmpty) 'set-cookie': cookies},
);
Matcher _kind(ApiFailureKind kind) =>
    throwsA(isA<ApiFailure>().having((e) => e.kind, 'kind', kind));
void main() {
  test('malformed QR query is sanitized as an invalid response', () async {
    final client = BiliAuthClient(
      adapter: _Adapter(
        (_) => _json({
          'qrcode_key': accountTicket().key,
          'url':
              'https://passport.bilibili.com/h5-app/passport/login/scan?qrcode_key=%FF',
        }),
      ),
    );
    addTearDown(client.close);
    await expectLater(client.createQr(), _kind(ApiFailureKind.invalidResponse));
  });
  test(
    'QR login uses exact passport endpoints, never fetches sensitive crossDomain URL; nav alone receives cookies',
    () async {
      final ticket = accountTicket();
      final adapter = _Adapter(
        (request) => switch (request.uri.path) {
          '/x/passport-login/web/qrcode/generate' => _json({
            'qrcode_key': ticket.key,
            'url': ticket.url.toString(),
          }),
          '/x/passport-login/web/qrcode/poll' => _json({
            'code': 0,
            'url':
                'https://passport.biligame.com/crossDomain?SESSDATA=never-follow',
            'refresh_token': 'fixture-refresh',
          }, cookies: _cookies()),
          '/x/web-interface/nav' => _json({
            'isLogin': true,
            'mid': 123,
            'uname': '测试账号',
          }),
          _ => throw StateError('Unexpected endpoint'),
        },
      );
      final client = BiliAuthClient(adapter: adapter);
      addTearDown(client.close);
      final qr = await client.createQr();
      final result = await client.poll(qr);
      expect(result.status, BiliQrStatus.confirmed);
      expect((await client.verify(result.credentials!)).mid, '123');
      expect(adapter.requests, hasLength(3));
      for (final request in adapter.requests) {
        expect(request.method, 'GET');
        expect(request.followRedirects, isFalse);
        expect(request.uri.scheme, 'https');
      }
      expect(
        adapter.requests.take(2).map((r) => r.uri.host),
        everyElement('passport.bilibili.com'),
      );
      expect(
        adapter.requests
            .take(2)
            .every(
              (r) => !r.headers.keys.any((k) => k.toLowerCase() == 'cookie'),
            ),
        isTrue,
      );
      expect(
        adapter.requests.last.headers['Cookie'],
        contains('SESSDATA=fixture-session'),
      );
      expect(result.toString(), isNot(contains('fixture-refresh')));
    },
  );
  for (final pair in {
    86101: BiliQrStatus.waiting,
    86090: BiliQrStatus.scanned,
    86038: BiliQrStatus.expired,
  }.entries) {
    test(
      'maps polling ${pair.key} without treating scanning as confirmation',
      () async {
        final client = BiliAuthClient(
          adapter: _Adapter((_) => _json({'code': pair.key})),
        );
        addTearDown(client.close);
        final result = await client.poll(accountTicket());
        expect(result.status, pair.value);
        expect(result.credentials, isNull);
      },
    );
  }
  test(
    'Set-Cookie parser rejects foreign domains, header syntax, conflicting values and missing essentials',
    () {
      for (final lines in [
        <String>[],
        _cookies()
            .map((c) => c.replaceAll('.bilibili.com', '.evilbilibili.com'))
            .toList(),
        [..._cookies(), 'SESSDATA=other; Domain=.bilibili.com; Path=/'],
        _cookies().map((c) => '$c; Max-Age=0').toList(),
        _cookies()
            .map((c) => '$c; Expires=Thu, 01 Jan 1970 00:00:00 GMT')
            .toList(),
      ]) {
        expect(
          () => BiliAuthClient.credentialsFromCookies(lines),
          throwsA(isA<AccountFailure>()),
        );
      }
      expect(BiliAuthClient.credentialsFromCookies(_cookies()).mid, '123');
    },
  );
  test(
    'wrong QR host/key and account identity never become credentials',
    () async {
      final evil = BiliAuthClient(
        adapter: _Adapter(
          (_) => _json({
            'qrcode_key': accountTicket().key,
            'url': 'https://evil.test/login',
          }),
        ),
      );
      addTearDown(evil.close);
      await expectLater(evil.createQr(), _kind(ApiFailureKind.invalidResponse));
      final mismatch = BiliAuthClient(
        adapter: _Adapter(
          (_) => _json({'isLogin': true, 'mid': 456, 'uname': 'other'}),
        ),
      );
      addTearDown(mismatch.close);
      await expectLater(
        mismatch.verify(accountCredentials()),
        _kind(ApiFailureKind.invalidResponse),
      );
      final expired = BiliAuthClient(
        adapter: _Adapter((_) => _json({'isLogin': false}, code: -101)),
      );
      addTearDown(expired.close);
      await expectLater(
        expired.verify(accountCredentials()),
        _kind(ApiFailureKind.loginRequired),
      );
    },
  );
  test(
    'shared auth 429 blocks polling before dispatch; redirect is not followed',
    () async {
      final adapter = _Adapter(
        (_) => ResponseBody.fromString(
          '',
          429,
          headers: {
            'retry-after': ['60'],
          },
        ),
      );
      final client = BiliAuthClient(adapter: adapter);
      addTearDown(client.close);
      await expectLater(client.createQr(), _kind(ApiFailureKind.rateLimited));
      await expectLater(
        client.poll(accountTicket()),
        _kind(ApiFailureKind.rateLimited),
      );
      expect(adapter.requests, hasLength(1));
      final redirect = _Adapter(
        (_) => ResponseBody.fromString(
          '',
          302,
          headers: {
            'location': ['https://evil.test/'],
          },
        ),
      );
      final other = BiliAuthClient(adapter: redirect);
      addTearDown(other.close);
      await expectLater(
        other.verify(accountCredentials()),
        _kind(ApiFailureKind.unavailable),
      );
      expect(redirect.requests, hasLength(1));
    },
  );
  test(
    'bounded response, silent stream deadline and cancellation sanitize failures',
    () async {
      final oversized = BiliAuthClient(
        adapter: _Adapter(
          (_) => ResponseBody.fromBytes(Uint8List(512 * 1024 + 1), 200),
        ),
      );
      addTearDown(oversized.close);
      await expectLater(
        oversized.createQr(),
        _kind(ApiFailureKind.invalidResponse),
      );
      final stream = StreamController<Uint8List>();
      final slow = BiliAuthClient(
        adapter: _Adapter((_) => ResponseBody(stream.stream, 200)),
        deadline: const Duration(milliseconds: 10),
      );
      addTearDown(slow.close);
      await expectLater(slow.createQr(), _kind(ApiFailureKind.timeout));
      await stream.close();
      final adapter = _Adapter((_) => _json({}));
      final client = BiliAuthClient(adapter: adapter);
      addTearDown(client.close);
      await expectLater(
        client.createQr(cancellation: RequestCancellation()..cancel()),
        _kind(ApiFailureKind.cancelled),
      );
      expect(adapter.requests, isEmpty);
    },
  );
  test(
    'metadata samples current credentials per request and never borrows auth state as a cookie jar',
    () async {
      BiliCredentials? current = accountCredentials();
      final adapter = _Adapter((_) => _json({'ok': true}));
      final metadata = BiliMetadataClient(
        adapter: adapter,
        credentials: () => current,
      );
      addTearDown(metadata.close);
      await metadata.get(BiliReadEndpoint.card);
      current = null;
      await metadata.get(BiliReadEndpoint.card);
      expect(
        adapter.requests.first.headers['Cookie'],
        contains('fixture-session'),
      );
      expect(
        adapter.requests.last.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('cookie')),
      );
    },
  );
}
