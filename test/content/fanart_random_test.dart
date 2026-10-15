import 'dart:convert';
import 'dart:typed_data';

import 'package:asasfans_next/core/network/public_api_client.dart';
import 'package:asasfans_next/features/content/data/dynamic_fanart_repository.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

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
  test('a sample is one random request with the filters, no cursor', () async {
    final base = Uri.parse('https://example.test/api/');
    final adapter = _Adapter([
      {'sourceDynamicId': '1'},
      {'sourceDynamicId': 'douban:2'},
      {'sourceDynamicId': '3'},
    ]);
    final dio = Dio(BaseOptions(baseUrl: base.toString()))
      ..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    final items =
        await DynamicFanartRepository(
          PublicApiClient(dio),
          baseUrl: base,
        ).sample(
          query: const FanartQuery(
            keyword: '生日',
            characters: {FanartCharacter.diana},
            limit: 10,
          ),
        );
    expect(items, hasLength(3));
    final query = adapter.request?.queryParameters;
    expect(query, containsPair('random', '1'));
    expect(query, containsPair('limit', 10));
    expect(query, containsPair('q', '生日'));
    expect(query, containsPair('character', '嘉然'));
    expect(query?.containsKey('cursor'), isFalse);
  });
}
