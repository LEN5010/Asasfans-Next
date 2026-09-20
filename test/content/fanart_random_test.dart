import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/core/network/public_api_client.dart';
import 'package:asasfans_next/features/content/data/dynamic_fanart_repository.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Pick implements Random {
  _Pick(this.index);
  final int index;
  @override
  int nextInt(int max) => index % max;
  @override
  bool nextBool() => index.isOdd;
  @override
  double nextDouble() => 0;
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.items);
  final List<Map<String, Object>> items;
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode({
        'items': items,
        'snapshot': {'id': 's'},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  for (final index in [0, 1]) {
    test(
      'union draw can pick source $index instead of always the Bilibili first row',
      () async {
        final base = Uri.parse('https://example.test/api/');
        final adapter = _Adapter([
          {'sourceDynamicId': '123'},
          {'sourceDynamicId': 'douban:456'},
        ]);
        final dio = Dio(BaseOptions(baseUrl: base.toString()))
          ..httpClientAdapter = adapter;
        addTearDown(() => dio.close(force: true));
        final repository = DynamicFanartRepository(
          PublicApiClient(dio),
          baseUrl: base,
          random: _Pick(index),
        );
        final item = await repository.random(
          query: const FanartQuery(
            keyword: '生日',
            characters: {FanartCharacter.diana},
          ),
        );
        expect(
          item?.identity.source,
          index == 0
              ? ContentSource.bilibiliDynamic
              : ContentSource.doubanTopic,
        );
        expect(adapter.request?.queryParameters, containsPair('random', '1'));
        expect(adapter.request?.queryParameters, containsPair('limit', 1));
        expect(adapter.request?.queryParameters, containsPair('q', '生日'));
        expect(
          adapter.request?.queryParameters,
          containsPair('character', '嘉然'),
        );
        expect(adapter.request?.queryParameters.containsKey('cursor'), isFalse);
      },
    );
  }

  test(
    'single nonempty source still returns a draw; no sources is a real empty result',
    () async {
      final base = Uri.parse('https://example.test/api/');
      for (final items in <List<Map<String, Object>>>[
        [],
        [
          {'sourceDynamicId': 'douban:1'},
        ],
      ]) {
        final dio = Dio(BaseOptions(baseUrl: base.toString()))
          ..httpClientAdapter = _Adapter(items);
        addTearDown(() => dio.close(force: true));
        final result = await DynamicFanartRepository(
          PublicApiClient(dio),
          baseUrl: base,
        ).random();
        expect(
          result?.identity.source,
          items.isEmpty ? null : ContentSource.doubanTopic,
        );
      }
    },
  );
}
