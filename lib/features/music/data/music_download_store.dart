import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;

import '../domain/music_track.dart';
import 'music_stream_repository.dart';

/// A song saved on this device, with the gain its stream reported, so
/// loudness matching works offline.
class MusicDownload {
  const MusicDownload({
    required this.track,
    required this.path,
    required this.gain,
    required this.bytes,
    required this.savedAt,
  });
  final MusicTrack track;
  final String path;
  final double gain;
  final int bytes;
  final DateTime savedAt;
}

/// Saved songs as files under the app's own support directory:
/// `<id>.<type>` for the audio and `<id>.json` beside it for what to show.
/// The sidecar is written last and removed first, so a song is listed only
/// while its audio is complete. Not part of the personal database or backups.
class MusicDownloadStore {
  MusicDownloadStore(this._dio, this._resolve);
  final Dio _dio;
  final Future<Directory> Function() _resolve;
  Directory? _directory;

  static final _safeId = RegExp(r'^[0-9A-Za-z_-]{1,64}$');

  Future<Directory> _dir() async {
    final directory = _directory ??= await _resolve();
    await directory.create(recursive: true);
    return directory;
  }

  /// Every complete download, newest first. Leftovers of an interrupted
  /// download or a deletion Windows refused while the file was open are
  /// removed here.
  Future<List<MusicDownload>> list() async {
    final directory = await _dir();
    final entities = await directory.list().toList();
    final listed = <MusicDownload>[];
    final kept = <String>{};
    for (final entity in entities) {
      if (entity is! File || path.extension(entity.path) != '.json') continue;
      final MusicDownload download;
      try {
        final value =
            jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
        final file = File(path.join(directory.path, value['file'] as String));
        if (!await file.exists()) continue;
        download = MusicDownload(
          track: MusicTrack(
            id: value['id'] as String,
            date: DateTime.parse(value['date'] as String),
            title: value['title'] as String,
            members: [for (final m in value['members'] as List) '$m'],
            duration: Duration(seconds: value['seconds'] as int),
            status: value['status'] as String,
          ),
          path: file.path,
          gain: (value['gain'] as num).toDouble(),
          bytes: await file.length(),
          savedAt: DateTime.fromMillisecondsSinceEpoch(value['saved'] as int),
        );
      } on Object {
        // Not a sidecar this app wrote whole; its files are cleared below.
        continue;
      }
      kept
        ..add(entity.path)
        ..add(download.path);
      listed.add(download);
    }
    for (final entity in entities) {
      if (entity is File && !kept.contains(entity.path)) {
        try {
          await entity.delete();
        } on FileSystemException {
          // Still open in the player on Windows; the next listing retries.
        }
      }
    }
    return listed..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }

  Future<MusicDownload> save(
    MusicTrack track,
    MusicStream stream, {
    CancelToken? cancel,
    void Function(int received, int total)? onProgress,
  }) async {
    if (!_safeId.hasMatch(track.id)) {
      throw ArgumentError.value(track.id, 'track.id');
    }
    final directory = await _dir();
    final name = '${track.id}.${stream.type}';
    final part = File(path.join(directory.path, '$name.part'));
    final meta = File(path.join(directory.path, '${track.id}.json.part'));
    try {
      await _dio.download(
        stream.uri.toString(),
        part.path,
        cancelToken: cancel,
        onReceiveProgress: onProgress,
      );
      final audio = await part.rename(path.join(directory.path, name));
      final saved = DateTime.now();
      await meta.writeAsString(
        jsonEncode({
          'id': track.id,
          'file': name,
          'date': track.date.toIso8601String(),
          'title': track.title,
          'members': track.members,
          'seconds': track.duration.inSeconds,
          'status': track.status,
          'gain': stream.gain,
          'saved': saved.millisecondsSinceEpoch,
        }),
        flush: true,
      );
      await meta.rename(path.join(directory.path, '${track.id}.json'));
      return MusicDownload(
        track: track,
        path: audio.path,
        gain: stream.gain,
        bytes: await audio.length(),
        savedAt: saved,
      );
    } on Object {
      for (final file in [part, meta]) {
        if (await file.exists()) await file.delete();
      }
      rethrow;
    }
  }

  /// Unlists the song, then frees its audio when the platform allows.
  Future<void> delete(MusicDownload download) async {
    final directory = await _dir();
    await File(path.join(directory.path, '${download.track.id}.json')).delete();
    try {
      await File(download.path).delete();
    } on FileSystemException {
      // Open in the player on Windows; [list] removes it later.
    }
  }
}
