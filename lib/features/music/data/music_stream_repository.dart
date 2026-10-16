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
    final response = await dio.get<Map<String, dynamic>>(
      'https://music.163.com/api/song/enhance/player/url',
      queryParameters: {'ids': '[${missing.join(',')}]', 'br': 320000},
      options: Options(headers: {'Cookie': 'os=pc'}),
    );
    final data = response.data?['data'];
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
