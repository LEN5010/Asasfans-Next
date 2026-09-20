import 'dart:typed_data';

import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/core/network/public_api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.response);
  final ResponseBody response;
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return response;
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'GET is scoped below the API prefix and does not attach credentials',
    () async {
      final adapter = _Adapter(
        ResponseBody.fromString(
          '{"items":[]}',
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      );
      final dio = Dio(
        BaseOptions(baseUrl: 'https://example.test/dynamics/api/'),
      )..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      await PublicApiClient(dio).get('fanart');
      expect(adapter.request?.uri.path, '/dynamics/api/fanart');
      expect(
        adapter.request?.headers.keys.map((key) => key.toLowerCase()),
        isNot(contains('cookie')),
      );
    },
  );

  for (final entry in {
    409: ApiFailureKind.datasetChanged,
    429: ApiFailureKind.rateLimited,
    503: ApiFailureKind.unavailable,
  }.entries) {
    test('maps HTTP ${entry.key} without exposing the response body', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
        ..httpClientAdapter = _Adapter(
          ResponseBody.fromString(
            'private server detail',
            entry.key,
            headers: {
              'retry-after': ['60'],
            },
          ),
        );
      addTearDown(() => dio.close(force: true));
      await expectLater(
        PublicApiClient(dio).get('fanart'),
        throwsA(
          isA<ApiFailure>().having((error) => error.kind, 'kind', entry.value),
        ),
      );
    });
  }

  test('rejects escaping the API base URL before dispatch', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/'));
    addTearDown(() => dio.close(force: true));
    for (final path in ['/fanart', '../admin', 'https://other.test/fanart']) {
      await expectLater(
        PublicApiClient(dio).get(path),
        throwsA(isA<ApiFailure>()),
      );
    }
  });
}
