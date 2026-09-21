import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:asasfans_next/core/bilibili/bili_metadata_client.dart';
import 'package:asasfans_next/core/domain/request_cancellation.dart';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/bili_fixture.dart' show imageKeyUrl, subKeyUrl;

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final FutureOr<ResponseBody> Function(RequestOptions) respond;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object data, {int code = 0}) =>
    ResponseBody.fromString(jsonEncode({'code': code, 'data': data}), 200);
Matcher _kind(ApiFailureKind kind) =>
    throwsA(isA<ApiFailure>().having((error) => error.kind, 'kind', kind));

void main() {
  test(
    'video and comment endpoints stay fixed GET-only, without signed media or write routes',
    () async {
      final adapter = _Adapter((_) => _json({}));
      final client = BiliMetadataClient(adapter: adapter);
      addTearDown(client.close);
      for (final endpoint in [
        BiliReadEndpoint.video,
        BiliReadEndpoint.comments,
        BiliReadEndpoint.commentReplies,
      ]) {
        await client.get(endpoint, parameters: const {'oid': '123'});
      }
      expect(adapter.requests.map((r) => r.uri.path), [
        '/x/web-interface/view',
        '/x/v2/reply',
        '/x/v2/reply/reply',
      ]);
      for (final request in adapter.requests) {
        expect(request.method, 'GET');
        expect(request.followRedirects, isFalse);
        expect(request.uri.host, 'api.bilibili.com');
        expect(request.headers.containsKey('Cookie'), isFalse);
      }
    },
  );
  test(
    'closed comment business code is retained rather than converted to empty data',
    () async {
      final client = BiliMetadataClient(
        adapter: _Adapter((_) => _json({}, code: 12002)),
      );
      addTearDown(client.close);
      await expectLater(
        client.get(BiliReadEndpoint.comments),
        throwsA(
          isA<ApiFailure>()
              .having((e) => e.code, 'code', '12002')
              .having((e) => e.kind, 'kind', ApiFailureKind.forbidden),
        ),
      );
    },
  );
  test(
    'isolated GET transport, exact signing and anonymous nav -101 exception',
    () async {
      final adapter = _Adapter(
        (request) => request.uri.path.endsWith('/nav')
            ? _json({
                'wbi_img': {'img_url': imageKeyUrl, 'sub_url': subKeyUrl},
              }, code: -101)
            : _json({'ok': true}),
      );
      final client = BiliMetadataClient(
        adapter: adapter,
        clock: () =>
            DateTime.fromMillisecondsSinceEpoch(1702204169000, isUtc: true),
      );
      addTearDown(client.close);
      await client.get(
        BiliReadEndpoint.archives,
        parameters: {'foo': '114', 'bar': '514', 'zab': '1919810'},
      );
      await client.get(BiliReadEndpoint.archives);
      expect(adapter.requests.map((request) => request.uri.path), [
        '/x/web-interface/nav',
        '/x/space/wbi/arc/search',
        '/x/space/wbi/arc/search',
      ]);
      expect(
        adapter.requests[1].uri.query,
        'bar=514&foo=114&wts=1702204169&zab=1919810&w_rid=8f6f2b5b3d485fe1886cec6a0be8c5d4',
      );
      for (final request in adapter.requests) {
        expect(request.uri.host, 'api.bilibili.com');
        expect(request.uri.scheme, 'https');
        expect(request.method, 'GET');
        expect(request.followRedirects, isFalse);
        expect(
          request.headers.keys.map((key) => key.toLowerCase()),
          isNot(anyOf(contains('cookie'), contains('authorization'))),
        );
      }
    },
  );
  for (final data in [
    {'v_voucher': 'fixture'},
    {'is_risk': true},
    {'gaia_res_type': 1},
  ]) {
    test('code zero risk payload is not an empty archive: $data', () async {
      final adapter = _Adapter((_) => _json(data));
      final client = BiliMetadataClient(adapter: adapter);
      addTearDown(client.close);
      await expectLater(
        client.get(BiliReadEndpoint.card),
        _kind(ApiFailureKind.riskControl),
      );
      expect(adapter.requests, hasLength(1));
    });
  }
  test(
    'signed risk invalidates keys for next explicit attempt, no automatic retry',
    () async {
      final adapter = _Adapter(
        (request) => request.uri.path.endsWith('/nav')
            ? _json({
                'wbi_img': {'img_url': imageKeyUrl, 'sub_url': subKeyUrl},
              }, code: -101)
            : _json({}, code: -412),
      );
      final client = BiliMetadataClient(adapter: adapter);
      addTearDown(client.close);
      await expectLater(
        client.get(BiliReadEndpoint.archives),
        _kind(ApiFailureKind.riskControl),
      );
      expect(adapter.requests, hasLength(2));
      await expectLater(
        client.get(BiliReadEndpoint.archives),
        _kind(ApiFailureKind.riskControl),
      );
      expect(adapter.requests, hasLength(4));
    },
  );
  test('nav-only -101 exception never hides missing login for card', () async {
    final client = BiliMetadataClient(
      adapter: _Adapter((_) => _json({}, code: -101)),
    );
    addTearDown(client.close);
    await expectLater(
      client.get(BiliReadEndpoint.card),
      _kind(ApiFailureKind.loginRequired),
    );
  });
  test('429 shares cooldown across endpoints before dispatch', () async {
    var now = DateTime.utc(2026);
    final adapter = _Adapter(
      (_) => ResponseBody.fromString(
        '',
        429,
        headers: {
          'retry-after': ['60'],
        },
      ),
    );
    final client = BiliMetadataClient(adapter: adapter, clock: () => now);
    addTearDown(client.close);
    await expectLater(
      client.get(BiliReadEndpoint.card),
      _kind(ApiFailureKind.rateLimited),
    );
    now = now.add(const Duration(seconds: 30));
    await expectLater(
      client.get(BiliReadEndpoint.archives),
      _kind(ApiFailureKind.rateLimited),
    );
    expect(adapter.requests, hasLength(1));
  });
  test('redirect response never sends a second request', () async {
    final adapter = _Adapter(
      (_) => ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': ['https://other.example.test/'],
        },
      ),
    );
    final client = BiliMetadataClient(adapter: adapter);
    addTearDown(client.close);
    await expectLater(
      client.get(BiliReadEndpoint.card),
      _kind(ApiFailureKind.unavailable),
    );
    expect(adapter.requests, hasLength(1));
  });
  test(
    'response byte cap cancels stream and malformed JSON is not exposed',
    () async {
      var cancelled = false;
      final chunks = StreamController<Uint8List>(
        onCancel: () {
          cancelled = true;
        },
      );
      final client = BiliMetadataClient(
        adapter: _Adapter((_) => ResponseBody(chunks.stream, 200)),
      );
      addTearDown(client.close);
      final request = client.get(BiliReadEndpoint.card);
      final assertion = expectLater(
        request,
        _kind(ApiFailureKind.invalidResponse),
      );
      chunks.add(Uint8List(BiliMetadataClient.maxBytes + 1));
      await assertion;
      expect(cancelled, isTrue);
      await chunks.close();
      final bad = BiliMetadataClient(
        adapter: _Adapter(
          (_) => ResponseBody.fromString('<html>fixture</html>', 200),
        ),
      );
      addTearDown(bad.close);
      await expectLater(
        bad.get(BiliReadEndpoint.card),
        _kind(ApiFailureKind.invalidResponse),
      );
    },
  );
  test('total deadline ends a silent stream and closes it', () async {
    var cancelled = false;
    final chunks = StreamController<Uint8List>(
      onCancel: () {
        cancelled = true;
      },
    );
    final client = BiliMetadataClient(
      adapter: _Adapter((_) => ResponseBody(chunks.stream, 200)),
      requestTimeout: const Duration(milliseconds: 10),
    );
    addTearDown(client.close);
    await expectLater(
      client.get(BiliReadEndpoint.card),
      _kind(ApiFailureKind.timeout),
    );
    expect(cancelled, isTrue);
    await chunks.close();
  });
  test('cancellation before dispatch and during body stops work', () async {
    var listened = false;
    final chunks = StreamController<Uint8List>(onListen: () => listened = true);
    final adapter = _Adapter((_) => ResponseBody(chunks.stream, 200));
    final client = BiliMetadataClient(adapter: adapter);
    addTearDown(client.close);
    final before = RequestCancellation()..cancel();
    await expectLater(
      client.get(BiliReadEndpoint.card, cancellation: before),
      _kind(ApiFailureKind.cancelled),
    );
    expect(adapter.requests, isEmpty);
    final during = RequestCancellation();
    final request = client.get(BiliReadEndpoint.card, cancellation: during);
    final assertion = expectLater(request, _kind(ApiFailureKind.cancelled));
    await Future<void>.delayed(Duration.zero);
    during.cancel();
    await assertion;
    // Cancelling this early means the body is abandoned before anything
    // subscribes to it, which is the point of the case. A single-subscription
    // stream that was never listened to cannot complete close(), so assert the
    // abandonment instead of awaiting a future that can never finish.
    expect(
      listened,
      isFalse,
      reason: 'a cancelled request must not start reading its body',
    );
    unawaited(chunks.close());
  });
}
