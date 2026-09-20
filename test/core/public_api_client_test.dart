import 'dart:typed_data';

import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/core/network/public_api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.response);
  final ResponseBody response;
  RequestOptions? request;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    calls++;
    return response;
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'one 429 blocks other routes on the same API client before dispatch',
    () async {
      var now = DateTime.utc(2026, 9, 21);
      final adapter = _Adapter(
        ResponseBody.fromString(
          '',
          429,
          headers: {
            'retry-after': ['60'],
          },
        ),
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
        ..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final client = PublicApiClient(dio, clock: () => now);
      await expectLater(client.get('fanart'), throwsA(isA<ApiFailure>()));
      now = now.add(const Duration(seconds: 30));
      await expectLater(
        client.get('search'),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.retryAfter,
            'remaining',
            const Duration(seconds: 30),
          ),
        ),
      );
      await expectLater(client.get('on-this-day'), throwsA(isA<ApiFailure>()));
      expect(adapter.calls, 1);
    },
  );
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

  group('Retry-After', () {
    final now = DateTime.utc(2026, 9, 21, 12);

    test('reads delta-seconds', () {
      expect(
        PublicApiClient.parseRetryAfter('60', now: now),
        const Duration(seconds: 60),
      );
      expect(PublicApiClient.parseRetryAfter('0', now: now), Duration.zero);
    });

    test('reads an HTTP-date as a delay from now', () {
      expect(
        PublicApiClient.parseRetryAfter(
          'Mon, 21 Sep 2026 12:00:30 GMT',
          now: now,
        ),
        const Duration(seconds: 30),
      );
    });

    test(
      'a past date means retry is already permitted, not a negative wait',
      () {
        expect(
          PublicApiClient.parseRetryAfter(
            'Mon, 21 Sep 2026 11:59:00 GMT',
            now: now,
          ),
          Duration.zero,
        );
      },
    );

    test('an unusable value yields no server guidance', () {
      for (final value in [null, '', '  ', '-5', 'soon', 'Mon, 99 Xxx 2026']) {
        expect(
          PublicApiClient.parseRetryAfter(value, now: now),
          isNull,
          reason: value.toString(),
        );
      }
    });
  });

  test(
    'surfaces the 409 discriminator so the two causes stay distinct',
    () async {
      for (final code in ['FANART_SNAPSHOT_CHANGED', 'FANART_STATS_CHANGED']) {
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
          ..httpClientAdapter = _Adapter(
            ResponseBody.fromString(
              '{"error":"changed","code":"$code"}',
              409,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            ),
          );
        addTearDown(() => dio.close(force: true));
        await expectLater(
          PublicApiClient(dio).get('fanart'),
          throwsA(
            isA<ApiFailure>()
                .having(
                  (error) => error.kind,
                  'kind',
                  ApiFailureKind.datasetChanged,
                )
                .having((error) => error.code, 'code', code),
          ),
        );
      }
    },
  );

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
