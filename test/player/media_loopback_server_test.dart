import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:asasfans_next/core/bilibili/bili_media_transport.dart';
import 'package:asasfans_next/features/player/data/media_loopback_server.dart';
import 'package:asasfans_next/features/player/domain/playback_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

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

ResponseBody _ok({
  int status = 200,
  List<int> bytes = const [1, 2, 3, 4, 5],
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

MediaResource _resource(List<String> urls) => MediaResource(
  locations: [for (final url in urls) Uri.parse(url)],
  refreshAfter: DateTime.utc(2030),
);

const _bvid = 'BV1xx411c7mD';
const _primary = 'https://primary.bilivideo.com/a.m4s?token=secret';
const _backup = 'https://backup.bilivideo.com/a.m4s?token=secret';

Future<HttpClientResponse> _get(
  Uri uri, {
  String method = 'GET',
  String? range,
}) async {
  final client = HttpClient();
  final request = await client.openUrl(method, uri);
  if (range != null) request.headers.set(HttpHeaders.rangeHeader, range);
  final response = await request.close();
  return response;
}

void main() {
  late MediaLoopbackServer server;

  Future<MediaLoopbackServer> start(_Adapter adapter) async {
    server = MediaLoopbackServer(BiliMediaTransport(adapter: adapter));
    await server.start();
    addTearDown(server.close);
    return server;
  }

  test('binds to loopback only and serves a registered resource', () async {
    final adapter = _Adapter((_) => _ok());
    await start(adapter);
    expect(server.base!.host, '127.0.0.1');

    final uri = server.register(_resource([_primary]), bvid: _bvid);
    final response = await _get(uri);
    expect(response.statusCode, 200);
    expect(await response.fold<List<int>>([], (a, b) => a..addAll(b)), [
      1,
      2,
      3,
      4,
      5,
    ]);
  });

  test('the upstream signed URL never reaches the local client', () async {
    final adapter = _Adapter((_) => _ok());
    await start(adapter);
    final uri = server.register(_resource([_primary]), bvid: _bvid);
    // The player only ever sees a loopback URL with an opaque path.
    expect(uri.toString(), isNot(contains('secret')));
    expect(uri.toString(), isNot(contains('bilivideo')));
    expect(uri.path, startsWith('/media/'));
  });

  test('an unknown path is refused rather than proxied', () async {
    final adapter = _Adapter((_) => _ok());
    await start(adapter);
    final response = await _get(server.base!.replace(path: '/media/guessed'));
    expect(response.statusCode, HttpStatus.notFound);
    expect(
      adapter.requests,
      isEmpty,
      reason: 'the relay must never be a general-purpose proxy',
    );
  });

  test('a method a player does not need is refused', () async {
    final adapter = _Adapter((_) => _ok());
    await start(adapter);
    final uri = server.register(_resource([_primary]), bvid: _bvid);
    final response = await _get(uri, method: 'DELETE');
    expect(response.statusCode, HttpStatus.notFound);
    expect(adapter.requests, isEmpty);
  });

  test('a range request is forwarded and its 206 preserved', () async {
    final adapter = _Adapter(
      (_) => _ok(
        status: 206,
        bytes: const [2, 3],
        headers: {
          'content-range': ['bytes 1-2/5'],
          'content-length': ['2'],
        },
      ),
    );
    await start(adapter);
    final uri = server.register(_resource([_primary]), bvid: _bvid);
    final response = await _get(uri, range: 'bytes=1-2');
    expect(response.statusCode, 206);
    expect(
      response.headers.value(HttpHeaders.contentRangeHeader),
      'bytes 1-2/5',
    );
    expect(adapter.requests.single.headers['range'], 'bytes=1-2');
  });

  test('HEAD returns headers without a body', () async {
    final adapter = _Adapter((_) => _ok());
    await start(adapter);
    final uri = server.register(_resource([_primary]), bvid: _bvid);
    final response = await _get(uri, method: 'HEAD');
    expect(response.statusCode, 200);
    expect(await response.fold<List<int>>([], (a, b) => a..addAll(b)), isEmpty);
  });

  test('a failed mirror falls back to the next location', () async {
    final adapter = _Adapter((options) {
      if (options.uri.host.startsWith('primary')) {
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'down',
        );
      }
      return _ok();
    });
    await start(adapter);
    final uri = server.register(_resource([_primary, _backup]), bvid: _bvid);
    final response = await _get(uri);
    expect(response.statusCode, 200);
    expect(adapter.requests, hasLength(2));
    expect(adapter.requests.last.uri.host, startsWith('backup'));
  });

  test(
    'exhausting every mirror reports a gateway failure, not a hang',
    () async {
      final adapter = _Adapter(
        (options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'down',
        ),
      );
      await start(adapter);
      final uri = server.register(_resource([_primary, _backup]), bvid: _bvid);
      final response = await _get(uri);
      expect(response.statusCode, HttpStatus.badGateway);
      expect(adapter.requests, hasLength(2));
    },
  );

  test('clear stops serving a previously registered track', () async {
    final adapter = _Adapter((_) => _ok());
    await start(adapter);
    final uri = server.register(_resource([_primary]), bvid: _bvid);
    server.clear();
    final response = await _get(uri);
    expect(
      response.statusCode,
      HttpStatus.notFound,
      reason: 'a late request must not keep pulling the previous track',
    );
  });

  test('each registration gets a distinct unguessable path', () async {
    final adapter = _Adapter((_) => _ok());
    await start(adapter);
    final first = server.register(_resource([_primary]), bvid: _bvid);
    final second = server.register(_resource([_primary]), bvid: _bvid);
    expect(first.path, isNot(second.path));
    expect(first.path.length, greaterThan(20));
  });

  test(
    'registering before start is refused instead of returning a dead URL',
    () {
      final early = MediaLoopbackServer(
        BiliMediaTransport(adapter: _Adapter((_) => _ok())),
      );
      addTearDown(early.close);
      expect(early.base, isNull);
      expect(
        () => early.register(_resource([_primary]), bvid: _bvid),
        throwsA(anything),
      );
    },
  );

  test('close releases the port', () async {
    final adapter = _Adapter((_) => _ok());
    await start(adapter);
    final base = server.base!;
    await server.close();
    expect(server.base, isNull);
    await expectLater(
      HttpClient()
          .getUrl(base.replace(path: '/media/x'))
          .then((r) => r.close()),
      throwsA(isA<SocketException>()),
    );
  });

  test('one bad request does not tear down the listener', () async {
    var fail = true;
    final adapter = _Adapter((options) {
      if (fail) {
        fail = false;
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'down',
        );
      }
      return _ok();
    });
    await start(adapter);
    final uri = server.register(_resource([_primary]), bvid: _bvid);
    final first = await _get(uri);
    expect(first.statusCode, HttpStatus.badGateway);
    // The listener is still serving afterwards.
    final second = await _get(uri);
    expect(second.statusCode, 200);
    expect(
      utf8.decode(
        await second.fold<List<int>>([], (a, b) => a..addAll(b)),
        allowMalformed: true,
      ),
      isNotEmpty,
    );
  });
}
