import 'dart:convert';

import 'package:dio/dio.dart';

class MusicStream {
  const MusicStream(this.uri, this.gain, this.expiresAt);
  final Uri uri;
  final double gain;
  final DateTime expiresAt;
}

class MusicStreamRepository {
  MusicStreamRepository(this.dio);
  final Dio dio;
  final _cache = <String, MusicStream>{};

  void invalidate(String id) => _cache.remove(id);
  Future<void> prefetch(Iterable<String> ids) async {
    final now = DateTime.now();
    _cache.removeWhere((_, item) => !item.expiresAt.isAfter(now));
    final missing = ids.where((id) => !_cache.containsKey(id)).toSet().toList();
    if (missing.isEmpty) return;
    // The answer is JSON served as text/plain, so it is decoded here rather
    // than left to the client's content-type sniffing. Without appver the
    // service reports every gain as 0 and loudness matching does nothing.
    final response = await dio.get<String>(
      'https://music.163.com/api/song/enhance/player/url',
      queryParameters: {'ids': '[${missing.join(',')}]', 'br': 320000},
      options: Options(
        responseType: ResponseType.plain,
        headers: {'Cookie': 'os=pc; appver=2.10.13'},
      ),
    );
    final body = jsonDecode(response.data ?? '');
    final data = body is Map<String, dynamic> ? body['data'] : null;
    if (data is! List<dynamic>) throw const FormatException('无法读取播放地址');
    for (final value in data) {
      if (value is! Map<String, dynamic> ||
          value['code'] != 200 ||
          value['url'] is! String) {
        continue;
      }
      var uri = Uri.tryParse(value['url'] as String);
      if (uri == null ||
          uri.host.isEmpty ||
          (uri.scheme != 'http' && uri.scheme != 'https')) {
        continue;
      }
      uri = uri.replace(scheme: 'https');
      _cache['${value['id']}'] = MusicStream(
        uri,
        (value['gain'] as num?)?.toDouble() ?? 0,
        now.add(const Duration(minutes: 20)),
      );
    }
  }

  Future<MusicStream?> resolve(String id) async {
    await prefetch([id]);
    return _cache[id];
  }
}
