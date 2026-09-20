import 'dart:async';
import 'dart:typed_data';
import 'package:asasfans_next/core/bilibili/bili_media_transport.dart';
import 'package:asasfans_next/core/bilibili/bili_credentials.dart';
import 'package:asasfans_next/core/domain/request_cancellation.dart';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/account_fixture.dart';
import '../helpers/video_comment_fixture.dart';

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

final _url = Uri.parse(
  'https://primary.bilivideo.com/fixture.mp4?token=fixture-private',
);
ResponseBody _ok({
  int status = 200,
  List<int> bytes = const [1, 2, 3, 4],
  Map<String, List<String>> headers = const {},
}) => ResponseBody.fromBytes(
  bytes,
  status,
  headers: {
    'content-type': ['video/mp4'],
    'content-length': ['${bytes.length}'],
    ...headers,
  },
);
Matcher _kind(ApiFailureKind kind) =>
    throwsA(isA<ApiFailure>().having((e) => e.kind, 'kind', kind));
void main() {
  test(
    'raw media stays lazy and propagates pause/resume instead of eagerly buffering',
    () async {
      final raw = StreamController<Uint8List>();
      addTearDown(raw.close);
      final transport = BiliMediaTransport(
        adapter: _Adapter((_) => ResponseBody(raw.stream, 200)),
        idleTimeout: const Duration(milliseconds: 20),
      );
      addTearDown(transport.close);
      final response = await transport.open(_url, bvid: fixtureBvid);
      expect(raw.hasListener, isFalse);
      final errors = <Object>[];
      final subscription = response.bytes.listen(
        (_) {},
        onError: (Object error) => errors.add(error),
      );
      expect(raw.hasListener, isTrue);
      subscription.pause();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(raw.isPaused, isTrue);
      expect(errors, isEmpty);
      subscription.resume();
      raw.add(Uint8List.fromList([1]));
      await Future<void>.delayed(Duration.zero);
      expect(raw.isPaused, isFalse);
      await subscription.cancel();
      expect(raw.hasListener, isFalse);
    },
  );
  test(
    'cancelled headers complete promptly and a late adapter response is discarded',
    () async {
      final pending = Completer<ResponseBody>();
      final raw = StreamController<Uint8List>();
      addTearDown(raw.close);
      var discarded = false;
      raw.onCancel = () => discarded = true;
      final transport = BiliMediaTransport(
        adapter: _Adapter((_) => pending.future),
      );
      addTearDown(transport.close);
      final cancel = RequestCancellation();
      final load = transport.open(
        _url,
        bvid: fixtureBvid,
        cancellation: cancel,
      );
      final cancelled = expectLater(load, _kind(ApiFailureKind.cancelled));
      cancel.cancel();
      await cancelled;
      pending.complete(ResponseBody(raw.stream, 200));
      await Future<void>.delayed(Duration.zero);
      expect(discarded, isTrue);
    },
  );
  test(
    'HEAD keeps content length metadata while an absent Content-Length on 206 still checks range byte count',
    () async {
      final adapter = _Adapter(
        (r) => r.method == 'HEAD'
            ? _ok(
                bytes: [],
                headers: {
                  'content-length': ['1000'],
                },
              )
            : ResponseBody.fromBytes(
                [1],
                206,
                headers: {
                  'content-type': ['video/mp4'],
                  'content-range': ['bytes 0-1/1000'],
                },
              ),
      );
      final transport = BiliMediaTransport(adapter: adapter);
      addTearDown(transport.close);
      final head = await transport.open(_url, bvid: fixtureBvid, head: true);
      expect(head.contentLength, 1000);
      expect(await head.bytes.toList(), isEmpty);
      final truncated = await transport.open(
        _url,
        bvid: fixtureBvid,
        range: 'bytes=0-1',
      );
      await expectLater(
        truncated.bytes.drain<void>(),
        _kind(ApiFailureKind.invalidResponse),
      );
    },
  );
  test(
    'headers are regenerated at every redirect and account changes are sampled, never forwarded',
    () async {
      BiliCredentials? credentials = accountCredentials();
      final adapter = _Adapter((request) {
        if (request.uri.host == 'primary.bilivideo.com') {
          return ResponseBody.fromBytes(
            [],
            302,
            headers: {
              'location': ['https://mirror.akamaized.net/media'],
            },
          );
        }
        if (request.uri.host == 'mirror.akamaized.net') {
          credentials = null;
          return ResponseBody.fromBytes(
            [],
            307,
            headers: {
              'location': ['https://last.bilivideo.com/media'],
            },
          );
        }
        return _ok();
      });
      final transport = BiliMediaTransport(
        adapter: adapter,
        credentials: () => credentials,
      );
      addTearDown(transport.close);
      final body = await transport.open(_url, bvid: fixtureBvid);
      expect(await body.bytes.expand((b) => b).toList(), [1, 2, 3, 4]);
      expect(
        adapter.requests.first.headers['Cookie'],
        contains('fixture-session'),
      );
      expect(
        adapter.requests.skip(1).every((r) => !r.headers.containsKey('Cookie')),
        isTrue,
      );
      for (final request in adapter.requests) {
        expect(request.followRedirects, isFalse);
        expect(request.method, 'GET');
        expect(
          request.headers['Referer'],
          'https://www.bilibili.com/video/$fixtureBvid',
        );
      }
    },
  );
  test(
    'downgrade, foreign URL and redirect cycle stop before the unsafe request',
    () async {
      for (final location in [
        'http://primary.bilivideo.com/v',
        'https://evil.test/v',
        _url.toString(),
      ]) {
        final adapter = _Adapter(
          (_) => ResponseBody.fromBytes(
            [],
            302,
            headers: {
              'location': [location],
            },
          ),
        );
        final transport = BiliMediaTransport(adapter: adapter);
        addTearDown(transport.close);
        await expectLater(
          transport.open(_url, bvid: fixtureBvid),
          _kind(ApiFailureKind.forbidden),
        );
        expect(adapter.requests, hasLength(1));
      }
    },
  );
  test('range semantics and full response fallback are preserved', () async {
    final adapter = _Adapter(
      (_) => _ok(
        status: 206,
        bytes: [3, 4],
        headers: {
          'content-range': ['bytes 2-3/4'],
        },
      ),
    );
    final transport = BiliMediaTransport(adapter: adapter);
    addTearDown(transport.close);
    final response = await transport.open(
      _url,
      bvid: fixtureBvid,
      range: 'bytes=2-',
    );
    expect(response.contentRange, 'bytes 2-3/4');
    expect(await response.bytes.expand((b) => b).toList(), [3, 4]);
    expect(adapter.requests.single.headers['Range'], 'bytes=2-');
    final full = BiliMediaTransport(adapter: _Adapter((_) => _ok()));
    addTearDown(full.close);
    final ignored = await full.open(_url, bvid: fixtureBvid, range: 'bytes=2-');
    expect(ignored.status, 200);
    expect(ignored.contentRange, isNull);
    await ignored.bytes.drain<void>();
  });
  test(
    'wrong ranges, non-media data and truncated bodies do not become successful video bytes',
    () async {
      for (final response in [
        _ok(
          status: 206,
          headers: {
            'content-range': ['bytes 2-5/6'],
          },
        ),
        _ok(
          headers: {
            'content-type': ['text/html'],
          },
        ),
      ]) {
        final transport = BiliMediaTransport(
          adapter: _Adapter((_) => response),
        );
        addTearDown(transport.close);
        await expectLater(
          transport.open(_url, bvid: fixtureBvid, range: 'bytes=0-3'),
          _kind(ApiFailureKind.invalidResponse),
        );
      }
      final transport = BiliMediaTransport(
        adapter: _Adapter(
          (_) => _ok(
            bytes: [1],
            headers: {
              'content-length': ['2'],
            },
          ),
        ),
      );
      addTearDown(transport.close);
      final response = await transport.open(_url, bvid: fixtureBvid);
      await expectLater(
        response.bytes.drain<void>(),
        _kind(ApiFailureKind.invalidResponse),
      );
    },
  );
  test(
    'long active stream has idle timeout only, no metadata whole-call deadline',
    () async {
      final adapter = _Adapter(
        (_) => ResponseBody(
          Stream<Uint8List>.periodic(
            const Duration(milliseconds: 25),
            (i) => Uint8List.fromList([i]),
          ).take(4),
          200,
          headers: {
            'content-type': ['video/mp4'],
          },
        ),
      );
      final transport = BiliMediaTransport(
        adapter: adapter,
        idleTimeout: const Duration(milliseconds: 70),
      );
      addTearDown(transport.close);
      final response = await transport.open(_url, bvid: fixtureBvid);
      expect(await response.bytes.expand((b) => b).toList(), [0, 1, 2, 3]);
    },
  );
  test(
    'cancellation/transport close revoke an active or unconsumed stream and release the slot',
    () async {
      final raw = StreamController<Uint8List>();
      addTearDown(raw.close);
      final adapter = _Adapter((_) => ResponseBody(raw.stream, 200));
      final transport = BiliMediaTransport(adapter: adapter, maxConcurrent: 1);
      addTearDown(transport.close);
      final cancellation = RequestCancellation();
      final response = await transport.open(
        _url,
        bvid: fixtureBvid,
        cancellation: cancellation,
      );
      final done = expectLater(
        response.bytes.drain<void>(),
        _kind(ApiFailureKind.cancelled),
      );
      cancellation.cancel();
      await done;
      final neverListened = BiliMediaTransport(adapter: _Adapter((_) => _ok()));
      final second = await neverListened.open(_url, bvid: fixtureBvid);
      neverListened.close();
      await expectLater(
        second.bytes.drain<void>(),
        _kind(ApiFailureKind.cancelled),
      );
    },
  );
  test(
    'HTTP 429 is shared and errors never leak request URL or headers',
    () async {
      final adapter = _Adapter(
        (_) => ResponseBody.fromBytes(
          [],
          429,
          headers: {
            'retry-after': ['60'],
          },
        ),
      );
      final transport = BiliMediaTransport(adapter: adapter);
      addTearDown(transport.close);
      await expectLater(
        transport.open(_url, bvid: fixtureBvid),
        _kind(ApiFailureKind.rateLimited),
      );
      await expectLater(
        transport.open(_url, bvid: fixtureBvid),
        _kind(ApiFailureKind.rateLimited),
      );
      expect(adapter.requests, hasLength(1));
      final error = BiliMediaTransport.failure(
        DioException(
          requestOptions: RequestOptions(
            path: _url.toString(),
            headers: {'Cookie': 'fixture-private'},
          ),
          message: 'fixture-private',
        ),
      );
      expect(error.toString(), isNot(contains('fixture-private')));
    },
  );
}
