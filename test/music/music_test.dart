import 'dart:convert';
import 'dart:io';

import 'package:asasfans_next/features/music/application/music_audio_handler.dart';
import 'package:asasfans_next/features/music/data/music_catalog_repository.dart';
import 'package:asasfans_next/features/music/data/music_stream_repository.dart';
import 'package:asasfans_next/features/music/domain/music_track.dart';
import 'package:dio/dio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// AudioService initializes its transitive artwork-cache plugin in this test.
// ignore: depend_on_referenced_packages
import 'package:sqflite/sqflite.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

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

class _StreamsFixture extends MusicStreamRepository {
  _StreamsFixture() : super(Dio());
  List<String> prefetched = [];

  @override
  Future<void> prefetch(Iterable<String> ids) async {
    prefetched = ids.toList();
  }

  @override
  Future<MusicStream?> resolve(String id) async =>
      MusicStream(Uri.parse('https://example.com/$id.mp3'), 0, DateTime(2100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('shuffle drives navigation, prefetch, edits and completion', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    void mock(String name, Future<Object?> Function(MethodCall) callback) {
      final channel = MethodChannel(name);
      messenger.setMockMethodCallHandler(channel, callback);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    }

    var events = '';
    final cache = await Directory.systemTemp.createTemp('asasfans-queue-');
    addTearDown(() => cache.delete(recursive: true));
    mock('plugins.flutter.io/path_provider', (_) async => cache.path);
    databaseFactory = databaseFactorySqflitePlugin;
    mock(
      'com.tekartik.sqflite',
      (call) async => switch (call.method) {
        'getDatabasesPath' => cache.path,
        'openDatabase' => {'id': 1},
        'query' =>
          (call.arguments as Map<Object?, Object?>)['sql'] ==
                  'PRAGMA user_version'
              ? [
                  {'user_version': 3},
                ]
              : <Map<String, Object?>>[],
        _ => null,
      },
    );
    Future<void> emit(int state) async {
      await messenger.handlePlatformMessage(
        events,
        const StandardMethodCodec().encodeSuccessEnvelope({
          'processingState': state,
          'updatePosition': 0,
          'updateTime': DateTime.now().millisecondsSinceEpoch,
          'bufferedPosition': 0,
          'duration': 180000000,
          'currentIndex': 0,
        }),
        (_) {},
      );
    }

    mock('com.ryanheise.audio_session', (_) async => null);
    mock('com.ryanheise.audio_service.client.methods', (_) async => null);
    mock('com.ryanheise.audio_service.handler.methods', (_) async => null);
    mock('com.ryanheise.just_audio.methods', (call) async {
      if (call.method == 'init') {
        final id = (call.arguments as Map<Object?, Object?>)['id'];
        events = 'com.ryanheise.just_audio.events.$id';
        mock(events, (_) async => null);
        mock('com.ryanheise.just_audio.data.$id', (_) async => null);
        mock('com.ryanheise.just_audio.methods.$id', (call) async {
          if (call.method == 'load') {
            await emit(3); // ready
            return {'duration': 180000000};
          }
          return <String, Object?>{};
        });
      }
      return <String, Object?>{};
    });
    final streams = _StreamsFixture();
    final handler = MusicAudioHandler(streams);
    final songs = List.generate(
      8,
      (i) => MusicTrack(
        id: '$i',
        title: 'song $i',
        members: const ['嘉然'],
        date: DateTime(2026, 10, 15),
        duration: const Duration(minutes: 3),
        status: '完整',
      ),
    );
    await handler.playTracks(songs, start: 3);
    expect(handler.message, isNull);
    await handler.setShuffleMode(AudioServiceShuffleMode.all);
    final order = handler.playOrder;
    expect(order.first, 3);
    expect(order.toSet(), List.generate(8, (i) => i).toSet());
    expect(handler.current, songs[3]);
    expect(
      handler.playbackState.value.shuffleMode,
      AudioServiceShuffleMode.all,
    );
    await handler.skipToNext();
    expect(handler.index, order[1]);
    expect(streams.prefetched, order.skip(1).take(3).map((i) => songs[i].id));
    await handler.skipToPrevious();
    expect(handler.index, 3);

    await handler.enqueue(songs.first, next: true);
    await handler.skipToNext();
    expect(handler.current, songs.first);
    await handler.removeTrack(handler.index);
    expect(handler.current, songs[order[1]]);
    await handler.removeTrack(0);
    expect(handler.playOrder.toSet(), List.generate(7, (i) => i).toSet());
    final current = handler.current;
    await handler.setShuffleMode(AudioServiceShuffleMode.none);
    expect(handler.current, current);
    expect(handler.playOrder, List.generate(7, (i) => i));

    await handler.playTracks(songs, shuffle: true);
    final shuffled = handler.playOrder;
    final visited = <int>{handler.index};
    final advanced = handler.playbackState.firstWhere(
      (s) =>
          s.queueIndex == shuffled[1] &&
          s.processingState == AudioProcessingState.ready,
    );
    await emit(4); // completed: follows the same order as the next button.
    await advanced;
    visited.add(handler.index);
    for (var i = 2; i < songs.length; i++) {
      await handler.skipToNext();
      expect(visited.add(handler.index), isTrue);
    }
    expect(visited, List.generate(8, (i) => i).toSet());
    await handler.skipToNext();
    expect(handler.index, shuffled.last);
    await handler.setRepeatMode(AudioServiceRepeatMode.all);
    await handler.skipToNext();
    expect(handler.index, shuffled.first);
    final large = List.generate(250, (i) => songs[i % songs.length]);
    await handler.playTracks(large, shuffle: true);
    expect(handler.tracks.length, MusicAudioHandler.maxQueue);
    expect(handler.playOrder.toSet(), List.generate(200, (i) => i).toSet());
    await handler.stop();
    handler.dispose();
    streams.dio.close();
    await DefaultCacheManager().getFileFromCache('unused');
    await DefaultCacheManager().dispose();
    await Future<void>.delayed(Duration.zero);
  });

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
    'stream requests batch ids, read the text/plain JSON and keep HTTPS URLs',
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
          // As the service really sends it.
          headers: {
            'content-type': ['text/plain;charset=UTF-8'],
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
      expect(
        adapter.requests.single.headers['Cookie'],
        'os=pc; appver=2.10.13',
      );
      expect(adapter.requests.single.queryParameters['ids'], '[123,124]');
      expect(musicVolume(-6), closeTo(.5012, .001));
    },
  );

  test('60% is the reference and positive loudness gain stays effective', () {
    expect(musicVolume(0), 1);
    expect(musicVolume(0, volume: .3), .5);
    expect(musicVolume(0, volume: 1), closeTo(1 / .6, .0001));
    expect(musicVolume(6), closeTo(1.9953, .001));
    expect(musicVolume(6, volume: 0), 0);
    // Equally loud sources after their respective corrections.
    expect(.1 * musicVolume(6), closeTo(.4 * musicVolume(-6), .001));
  });

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
    expect(sessions.map((s) => s.tracks.map((t) => t.id).join()), ['c', 'abd']);
    expect(sessions.last.members, ['嘉然', '贝拉', '乃琳']);
    expect(
      musicSessions(
        sessions.expand((s) => s.tracks),
        oldest: true,
      ).first.tracks.map((t) => t.id),
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
