import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/music_track.dart';

const musicCatalogMaxBytes = 16 * 1024 * 1024;
const musicCatalogMaxRows = 20000;

class MusicCatalog {
  const MusicCatalog(this.tracks, {this.warning});
  final List<MusicTrack> tracks;
  final String? warning;
}

class MusicCatalogRepository {
  MusicCatalogRepository(this.dio, {this.cacheFile});
  final Dio dio;
  final File? cacheFile;

  Future<MusicCatalog> load() async {
    final file =
        cacheFile ??
        File(
          '${(await getApplicationSupportDirectory()).path}/asasfans_flutter/music_catalog.json',
        );
    List<MusicTrack>? cached;
    String? etag;
    try {
      if (await file.exists() &&
          await file.length() <= musicCatalogMaxBytes * 2) {
        final text = await file.readAsString();
        final data = await Isolate.run(
          () => jsonDecode(text) as Map<String, dynamic>,
        );
        final raw = data['csv'] as String;
        cached = await Isolate.run(() => parseMusicCsv(raw));
        etag = data['etag'] as String?;
      }
    } on Object {
      // An invalid disk cache is never used as a successful catalogue.
      cached = null;
      etag = null;
    }
    try {
      final response = await dio.get<ResponseBody>(
        'https://api.asoul.us.kg/studio/song_database.csv',
        options: Options(
          responseType: ResponseType.stream,
          headers: {'If-None-Match': ?etag},
          validateStatus: (status) => status == 200 || status == 304,
        ),
      );
      if (response.statusCode == 304 && cached != null) {
        return MusicCatalog(cached);
      }
      final bytes = <int>[];
      await for (final chunk in response.data!.stream) {
        if (bytes.length + chunk.length > musicCatalogMaxBytes) {
          throw const FormatException('歌单过大');
        }
        bytes.addAll(chunk);
      }
      final raw = utf8.decode(bytes);
      final tracks = await Isolate.run(() => parseMusicCsv(raw));
      final payload = jsonEncode({
        'csv': raw,
        'etag': response.headers.value('etag'),
      });
      try {
        await file.parent.create(recursive: true);
        final temporary = File('${file.path}.tmp');
        await temporary.writeAsString(payload, flush: true);
        await temporary.rename(file.path);
      } on FileSystemException {
        // Only the next offline start loses out; this list is current.
      }
      return MusicCatalog(tracks);
    } on Object {
      if (cached != null) {
        return MusicCatalog(cached, warning: '歌单更新失败，正在使用上次缓存');
      }
      throw const FormatException('暂时无法读取歌单，请重试');
    }
  }
}

List<MusicTrack> parseMusicCsv(String raw) {
  if (raw.length > musicCatalogMaxBytes) throw const FormatException('歌单过大');
  final rows = <List<String>>[];
  var row = <String>[];
  var field = StringBuffer();
  var quoted = false;
  for (var i = 0; i < raw.length; i++) {
    final c = raw[i];
    if (c == '"') {
      if (quoted && i + 1 < raw.length && raw[i + 1] == '"') {
        field.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (c == ',' && !quoted) {
      row.add(field.toString());
      field = StringBuffer();
    } else if ((c == '\n' || c == '\r') && !quoted) {
      if (c == '\r' && i + 1 < raw.length && raw[i + 1] == '\n') i++;
      row.add(field.toString());
      if (row.any((v) => v.trim().isNotEmpty)) rows.add(row);
      if (rows.length > musicCatalogMaxRows + 1) {
        throw const FormatException('歌单行数过多');
      }
      row = [];
      field = StringBuffer();
    } else {
      field.write(c);
    }
  }
  if (quoted) throw const FormatException('歌单 CSV 不完整');
  row.add(field.toString());
  if (row.any((v) => v.trim().isNotEmpty)) rows.add(row);
  if (rows.isEmpty || rows.length > musicCatalogMaxRows + 1) {
    throw const FormatException('歌单为空或行数过多');
  }
  final header = rows.first
      .map((v) => v.replaceFirst('\uFEFF', '').trim())
      .toList();
  const required = ['id', '日期', '结束时间点', '歌名', '演唱者', '演唱状态', '有没有音频'];
  for (final name in required) {
    if (!header.contains(name)) throw FormatException('歌单缺少 $name');
  }
  final columns = {for (final name in required) name: header.indexOf(name)};
  final tracks = <MusicTrack>[];
  final ids = <String>{};
  // The catalogue is kept by hand: a row with a missing title or a bad date
  // is left out on its own instead of failing the whole list.
  for (final row in rows.skip(1)) {
    String value(String name) =>
        columns[name]! < row.length ? row[columns[name]!].trim() : '';
    if (value('有没有音频').toUpperCase() != 'TRUE') continue;
    final id = value('id');
    final title = value('歌名');
    final duration = double.tryParse(value('结束时间点'));
    final numbers = value('日期').split(RegExp(r'[./-]')).map(int.tryParse);
    final members = value('演唱者')
        .split(RegExp(r'[,，、]'))
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList();
    if (!RegExp(r'^\d+$').hasMatch(id) ||
        title.isEmpty ||
        duration == null ||
        duration <= 0 ||
        members.isEmpty ||
        numbers.length != 3 ||
        numbers.contains(null)) {
      continue;
    }
    final [year!, month!, day!] = numbers.toList();
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) continue;
    if (ids.add(id)) {
      tracks.add(
        MusicTrack(
          id: id,
          date: date,
          title: title,
          members: List.unmodifiable(members),
          duration: Duration(milliseconds: duration.round()),
          status: value('演唱状态'),
        ),
      );
    }
  }
  if (tracks.isEmpty) throw const FormatException('歌单没有可播放的歌回');
  return List.unmodifiable(tracks);
}
