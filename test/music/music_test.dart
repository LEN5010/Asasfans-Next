import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:asasfans_next/features/music/data/music_catalog_repository.dart';
import 'package:asasfans_next/features/music/data/music_stream_repository.dart';
import 'package:asasfans_next/features/music/domain/music_track.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const _csv =
    'id,日期,结束时间点,歌名,演唱者,演唱状态,有没有音频\r\n'
    '123,2026.10.15,120000,"歌名, 含""引号""","嘉然,乃琳",Live,TRUE\r\n'
    '124,2026.10.15,90000,无音频,贝拉,完整,FALSE\r\n';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.responses);
  final List<ResponseBody> responses;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return responses.removeAt(0);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('CSV preserves quoted values and admits only audio rows', () {
    final tracks = parseMusicCsv('\uFEFF$_csv');
    expect(tracks, hasLength(1));
    expect(tracks.single.title, '歌名, 含"引号"');
    expect(tracks.single.members, ['嘉然', '乃琳']);
    expect(tracks.single.duration, const Duration(minutes: 2));
    expect(tracks.single.isLive, isTrue);
    expect(() => parseMusicCsv('id,歌名\n123,歌'), throwsFormatException);
    // The live catalogue has rows without a title; they drop out alone.
    final mixed = parseMusicCsv(
      '$_csv'
      '125,2024.12.15,225264,,思诺,完整,TRUE\r\n'
      '126,2024.2.30,225264,坏日期,思诺,完整,TRUE\r\n'
      '127,2024.12.15,225264,好歌,思诺,完整,TRUE\r\n',
    );
    expect(mixed.map((track) => track.id), ['123', '127']);
    expect(
      () => parseMusicCsv(_csv.replaceFirst('2026.10.15', '2026.2.30')),
      throwsFormatException,
    );
  });

  test(
    'cache keeps its valid catalogue after a broken update and sends ETag',
    () async {
      final dir = await Directory.systemTemp.createTemp('asasfans-music-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/catalog.json');
      final adapter = _Adapter([
        ResponseBody.fromString(
          _csv,
          200,
          headers: {
            'etag': ['"v1"'],
          },
        ),
        ResponseBody.fromString('missing,columns', 200),
        ResponseBody.fromString('', 304),
      ]);
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final repository = MusicCatalogRepository(dio, cacheFile: file);
      expect((await repository.load()).tracks, hasLength(1));
      final goodCache = await file.readAsString();
      final stale = await repository.load();
      expect(stale.tracks.single.id, '123');
      expect(stale.warning, isNotNull);
      expect(await file.readAsString(), goodCache);
      expect(adapter.requests[1].headers['If-None-Match'], '"v1"');
      expect((await repository.load()).warning, isNull);
    },
  );

  test(
    'stream requests batch ids with os=pc and cache only valid HTTPS URLs',
    () async {
      final adapter = _Adapter([
        ResponseBody.fromString(
          jsonEncode({
            'data': [
              {
                'id': 123,
                'code': 200,
                'url': 'http://music.example/audio.mp3',
                'gain': -6.0,
              },
              {'id': 124, 'code': 404, 'url': null},
            ],
          }),
          200,
          headers: {
            'content-type': ['application/json'],
          },
        ),
      ]);
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final repository = MusicStreamRepository(dio);
      await repository.prefetch(['123', '124']);
      final stream = await repository.resolve('123');
      expect(stream!.uri.scheme, 'https');
      expect(stream.gain, -6);
      expect(adapter.requests.single.headers['Cookie'], 'os=pc');
      expect(adapter.requests.single.queryParameters['ids'], '[123,124]');
      expect(musicVolume(-6), closeTo(.5012, .001));
      expect(musicVolume(5.3), 1);
    },
  );

  test('a day is one session, in catalogue order, newest day first', () {
    MusicTrack song(String id, DateTime date, List<String> members) =>
        MusicTrack(
          id: id,
          date: date,
          title: id,
          members: members,
          duration: const Duration(minutes: 3),
          status: '完整',
        );
    final sessions = musicSessions([
      song('a', DateTime(2026, 9, 5), ['嘉然', '贝拉']),
      song('b', DateTime(2026, 9, 5), ['乃琳']),
      song('c', DateTime(2026, 9, 9), ['贝拉']),
      song('d', DateTime(2026, 9, 5), ['嘉然', '贝拉']),
    ]);
    expect(sessions.map((s) => s.tracks.map((t) => t.id).join()), [
      'c',
      'abd',
    ]);
    expect(sessions.last.members, ['嘉然', '贝拉', '乃琳']);
    expect(
      musicSessions(sessions.expand((s) => s.tracks), oldest: true)
          .first
          .tracks
          .map((t) => t.id),
      ['a', 'b', 'd'],
    );
  });

  test('studio search rules use new group names and Beijing date bounds', () {
    MusicTrack song(List<String> members) => MusicTrack(
      id: '1',
      date: DateTime(2026, 6, 20),
      title: '歌名',
      members: members,
      duration: const Duration(minutes: 3),
      status: '完整',
    );
    expect(musicSearchMembers(song(['嘉然', '贝拉', '乃琳'])), 'A-SOUL');
    expect(musicSearchMembers(song(['嘉然', '贝拉', '乃琳', '心宜', '思诺'])), '枝江');
    final mobile = musicSearchLink(song(['嘉然']), replay: false, mobile: true);
    expect(mobile.queryParameters['keyword'], '歌名 嘉然 2026.6');
    final desktop = musicSearchLink(
      song(['嘉然']),
      replay: true,
      mobile: false,
      now: DateTime.utc(2026, 6, 22),
    );
    expect(desktop.queryParameters['duration'], '4');
    expect(
      desktop.queryParameters['pubtime_begin_s'],
      '${DateTime.utc(2026, 6, 19, 16).millisecondsSinceEpoch ~/ 1000}',
    );
    expect(
      desktop.queryParameters['pubtime_end_s'],
      '${DateTime.utc(2026, 6, 22).millisecondsSinceEpoch ~/ 1000}',
    );
  });
}
