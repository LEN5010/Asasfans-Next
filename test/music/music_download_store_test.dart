import 'dart:io';

import 'package:asasfans_next/features/music/data/music_download_store.dart';
import 'package:asasfans_next/features/music/data/music_stream_repository.dart';
import 'package:asasfans_next/features/music/domain/music_track.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  test(
    'a saved song lists with its gain; leftovers and deletions are cleared',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) {
        request.response
          ..headers.contentLength = 4
          ..add([1, 2, 3, 4]);
        request.response.close();
      });
      final root = await Directory.systemTemp.createTemp('music_downloads');
      addTearDown(() => root.delete(recursive: true));
      final store = MusicDownloadStore(Dio(), () async => root);
      final track = MusicTrack(
        id: '123',
        date: DateTime(2026, 10, 15),
        title: '小幸运',
        members: const ['嘉然'],
        duration: const Duration(minutes: 4),
        status: 'Live',
      );
      final saved = await store.save(
        track,
        MusicStream(
          Uri.parse('http://127.0.0.1:${server.port}/a.flac'),
          -3.5,
          DateTime.now(),
          type: 'flac',
        ),
      );
      expect(path.basename(saved.path), '123.flac');
      // An interrupted download and an orphaned audio file.
      await File(path.join(root.path, '9.mp3.part')).writeAsBytes([0]);
      await File(path.join(root.path, '8.mp3')).writeAsBytes([0]);

      final listed = await store.list();
      expect(listed.single.track.title, '小幸运');
      expect(listed.single.track.members, ['嘉然']);
      expect(listed.single.gain, -3.5);
      expect(listed.single.bytes, 4);
      expect(root.listSync().map((e) => path.basename(e.path)).toSet(), {
        '123.flac',
        '123.json',
      });

      await store.delete(listed.single);
      expect(await store.list(), isEmpty);
      expect(root.listSync(), isEmpty);
    },
  );
}
