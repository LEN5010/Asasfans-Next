import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/music_download_store.dart';
import '../data/music_stream_repository.dart';
import '../domain/music_track.dart';

/// Songs saved for offline play, and those still downloading. The player
/// asks [of] before it requests a stream.
class MusicDownloads extends ChangeNotifier {
  MusicDownloads(this._store, this._streams);
  final MusicDownloadStore _store;
  final MusicStreamRepository _streams;
  var _done = <String, MusicDownload>{};
  final _progress = <String, double>{};
  final _cancels = <String, CancelToken>{};
  Future<void>? _loading;
  bool _loaded = false;
  bool _failed = false;
  bool _disposed = false;

  bool get loaded => _loaded;

  /// The saved songs could not be read.
  bool get failed => _failed;

  /// Newest first.
  List<MusicDownload> get items =>
      _done.values.toList()..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  int get bytes => _done.values.fold(0, (sum, item) => sum + item.bytes);
  MusicDownload? of(String id) => _done[id];

  /// 0–1 while [id] is downloading.
  double? progressOf(String id) => _progress[id];

  Future<void> load() => _loading ??= _read();

  Future<void> _read() async {
    try {
      final items = await _store.list();
      _done = {for (final item in items) item.track.id: item};
    } on Object {
      _failed = true;
    }
    _loaded = true;
    _notify();
  }

  /// Saves [track]. Returns why it failed, or null once saved or cancelled.
  Future<String?> download(MusicTrack track) async {
    final id = track.id;
    // The listing clears unfinished files, so it runs before any download.
    await load();
    if (_failed) return '无法读取本机已下载的歌';
    if (_done.containsKey(id) || _progress.containsKey(id)) return null;
    final cancel = _cancels[id] = CancelToken();
    _progress[id] = 0;
    _notify();
    try {
      final stream = await _streams.resolve(id);
      if (stream == null) return '「${track.title}」暂时无法下载';
      var shown = 0;
      _done[id] = await _store.save(
        track,
        stream,
        cancel: cancel,
        onProgress: (received, total) {
          if (total <= 0) return;
          final percent = received * 100 ~/ total;
          if (percent == shown) return;
          shown = percent;
          _progress[id] = received / total;
          _notify();
        },
      );
      return null;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) return null;
      _streams.invalidate(id);
      return '「${track.title}」下载失败，请检查网络';
    } on Object {
      return '「${track.title}」下载失败';
    } finally {
      _progress.remove(id);
      _cancels.remove(id);
      _notify();
    }
  }

  void cancel(String id) => _cancels[id]?.cancel();

  /// Returns why it failed, or null once removed.
  Future<String?> delete(String id) async {
    final item = _done[id];
    if (item == null) return null;
    try {
      await _store.delete(item);
    } on Object {
      return '「${item.track.title}」删除失败';
    }
    _done.remove(id);
    _notify();
    return null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final token in _cancels.values) {
      token.cancel();
    }
    super.dispose();
  }
}
