import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as audio;
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

import '../data/music_stream_repository.dart';
import '../domain/music_track.dart';

/// A runtime-only queue. Signed stream URLs never enter media metadata or disk.
class MusicAudioHandler extends BaseAudioHandler with ChangeNotifier {
  MusicAudioHandler(this._streams);
  final MusicStreamRepository _streams;
  audio.AudioPlayer? _engine;
  audio.AudioPlayer get _player => _engine!;
  audio.AndroidLoudnessEnhancer? _enhancer;
  Future<void>? _ready;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  List<MusicTrack> _tracks = [];
  List<MusicTrack> get tracks => UnmodifiableListView(_tracks);
  int _index = -1;
  int get index => _index;
  MusicTrack? get current =>
      _index >= 0 && _index < _tracks.length ? _tracks[_index] : null;
  bool get playing => _engine?.playing ?? false;
  Duration get position => _engine?.position ?? Duration.zero;
  Duration get duration =>
      _engine?.duration ?? current?.duration ?? Duration.zero;
  bool get loading => _loading;
  bool _loading = false;
  bool _recovering = false;
  bool _retried = false;
  bool _loudness = true;
  double _gain = 0;
  double _volume = .6;
  int _generation = 0;
  bool _disposed = false;

  /// The latest notice for the user, and a serial that changes with each
  /// one, so the same words twice in a row still show twice.
  String? message;
  int messageSerial = 0;
  void _say(String text) {
    message = text;
    messageSerial++;
    notifyListeners();
  }

  /// Most songs a queue holds: the platform media session copies the whole
  /// queue across processes, and the catalogue has thousands.
  static const maxQueue = 200;
  AudioServiceRepeatMode _repeat = AudioServiceRepeatMode.none;
  AudioServiceRepeatMode get repeat => _repeat;
  bool _shuffled = false;
  bool get shuffled => _shuffled;
  List<int> _order = [];
  List<int> get playOrder => _shuffled
      ? List.unmodifiable(_order)
      : List.generate(tracks.length, (i) => i);

  void _shuffleOrder() {
    _order = List.generate(_tracks.length, (i) => i)..remove(_index);
    _order.shuffle();
    if (_index >= 0) _order.insert(0, _index);
  }

  int? get _nextIndex {
    final order = playOrder;
    final at = order.indexOf(_index) + 1;
    return at < order.length ? order[at] : null;
  }

  Future<void> _initialize() async {
    try {
      if (Platform.isWindows) {
        JustAudioMediaKit.ensureInitialized(linux: false, windows: true);
      }
      _enhancer = Platform.isAndroid ? audio.AndroidLoudnessEnhancer() : null;
      _engine = audio.AudioPlayer(
        audioPipeline: audio.AudioPipeline(androidAudioEffects: [?_enhancer]),
      );
      _subscriptions.add(_player.playbackEventStream.listen((_) => _publish()));
      _subscriptions.add(
        _player.positionStream.listen((_) => notifyListeners()),
      );
      _subscriptions.add(
        _player.processingStateStream.listen((state) {
          if (state == audio.ProcessingState.completed && !_loading) {
            unawaited(_completed());
          }
        }),
      );
      _subscriptions.add(
        _player.errorStream.listen((_) {
          if (!_loading) unawaited(_recover());
        }),
      );
      if (!Platform.isWindows) {
        await AudioService.init<MusicAudioHandler>(
          builder: () => this,
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'asasfans.music',
            androidNotificationChannelName: '歌回播放',
            androidNotificationOngoing: false,
            androidStopForegroundOnPause: false,
          ),
        );
      }
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      _subscriptions.add(
        session.becomingNoisyEventStream.listen((_) => unawaited(pause())),
      );
    } on Object {
      _initFailed = true;
      rethrow;
    }
  }

  bool _initFailed = false;

  /// Plays [values] from [start]. A short list such as a day is queued
  /// whole, so 上一首 reaches the songs before; a long one is cut to the next
  /// [maxQueue] songs from the one chosen. Explicit [shuffle] samples the
  /// whole list; otherwise the current shuffle mode stays in effect.
  Future<void> playTracks(
    List<MusicTrack> values, {
    int start = 0,
    bool? shuffle,
  }) async {
    if (values.isEmpty) return;
    if (shuffle != null) _shuffled = shuffle;
    if (shuffle == true) {
      // Sample the whole filtered list before applying the queue limit.
      final candidates = List.generate(values.length, (i) => i)..shuffle();
      final chosen = candidates.take(maxQueue).toList();
      final first = chosen.first;
      chosen.sort();
      _tracks = [for (final i in chosen) values[i]];
      _index = chosen.indexOf(first);
    } else {
      final from = start.clamp(0, values.length - 1);
      final window = values.length <= maxQueue ? 0 : from;
      _tracks = values.skip(window).take(maxQueue).toList();
      _index = from - window;
    }
    if (_shuffled) _shuffleOrder();
    _publishQueue();
    await _load();
  }

  Future<void> enqueue(MusicTrack track, {bool next = false}) async {
    if (_tracks.isEmpty) {
      await playTracks([track]);
      return;
    }
    final insert = next ? _index + 1 : _tracks.length;
    _tracks.insert(insert, track);
    if (_shuffled) {
      _order = [for (final i in _order) i >= insert ? i + 1 : i];
      _order.insert(next ? _order.indexOf(_index) + 1 : _order.length, insert);
    }
    _publishQueue();
    _say(next ? '已设为下一首' : '已加入队列');
  }

  Future<void> removeTrack(int at) async {
    if (at < 0 || at >= _tracks.length) return;
    final wasCurrent = at == _index;
    final order = playOrder;
    final position = order.indexOf(at);
    final successor = wasCurrent && order.length > 1
        ? order[position + 1 < order.length ? position + 1 : position - 1]
        : _index;
    _tracks.removeAt(at);
    if (_shuffled) {
      _order = [
        for (final i in _order)
          if (i != at) i > at ? i - 1 : i,
      ];
    }
    if (_tracks.isEmpty) {
      _index = -1;
      await stop();
      mediaItem.add(null);
    } else if (at < _index) {
      _index--;
    } else if (wasCurrent) {
      _index = successor > at ? successor - 1 : successor;
      await _load();
    }
    _publishQueue();
  }

  /// Opens the current song and, unless [resume] is false, plays it. A song
  /// the service will not serve is skipped, at most twice in a row; a request
  /// that fails outright stops instead, so an offline queue is not walked.
  Future<void> _load({
    Duration at = Duration.zero,
    bool retry = false,
    bool resume = true,
  }) async {
    final generation = ++_generation;
    if (!retry) _retried = false;
    for (var skipped = 0; ; skipped++) {
      final song = current;
      if (song == null) return;
      _loading = true;
      mediaItem.add(_media(song));
      _publish();
      final outcome = await _open(
        song,
        generation,
        at: skipped == 0 ? at : Duration.zero,
        resume: resume,
      );
      if (outcome == null) return;
      _loading = false;
      switch (outcome) {
        case _Open.playing:
          _publish();
          return;
        case _Open.failed:
          await _engine?.stop();
          _publish();
          _say(_initFailed ? '音乐播放初始化失败' : '网络连接失败，「${song.title}」暂时无法播放');
          return;
        case _Open.unavailable:
          if (skipped >= 2 || _nextIndex == null) {
            await _engine?.stop();
            _publish();
            _say('「${song.title}」暂时无法播放');
            return;
          }
          _say('「${song.title}」暂时无法播放，已跳到下一首');
          _index = _nextIndex!;
      }
    }
  }

  /// One song, tried twice. Null when a newer load took over.
  Future<_Open?> _open(
    MusicTrack song,
    int generation, {
    required Duration at,
    required bool resume,
  }) async {
    bool stale() => generation != _generation || _disposed;
    for (var attempt = 0; attempt < 2; attempt++) {
      MusicStream? stream;
      try {
        _ready ??= _initialize();
        await _ready;
        await _engine?.pause();
        if (stale()) return null;
        final order = playOrder;
        await _streams.prefetch(
          order.skip(order.indexOf(_index)).take(3).map((i) => _tracks[i].id),
        );
        stream = await _streams.resolve(song.id);
      } on Object {
        if (stale()) return null;
        if (_initFailed || attempt == 1) return _Open.failed;
        continue;
      }
      if (stale()) return null;
      if (stream == null) return _Open.unavailable;
      try {
        _gain = stream.gain;
        await _player.setUrl(stream.uri.toString(), initialPosition: at);
        if (stale()) return null;
        await _applyLoudness();
        if (resume) {
          unawaited(
            _player.play().catchError((Object _) {
              if (!_loading) unawaited(_recover());
            }),
          );
        }
        return _Open.playing;
      } on Object {
        if (stale()) return null;
        _streams.invalidate(song.id);
      }
    }
    return _Open.unavailable;
  }

  Future<void> _recover() async {
    if (_recovering || current == null) return;
    _recovering = true;
    try {
      if (_retried) {
        final title = current!.title;
        if (_nextIndex != null) {
          _say('「$title」播放中断，已跳到下一首');
          _index = _nextIndex!;
          await _load();
        } else {
          await _engine?.stop();
          _say('「$title」播放中断');
        }
      } else {
        _retried = true;
        final position = _player.position;
        final resume = _player.playing;
        _streams.invalidate(current!.id);
        await _load(at: position, retry: true, resume: resume);
      }
    } finally {
      _recovering = false;
      _publish();
    }
  }

  Future<void> _completed() async {
    if (_repeat == AudioServiceRepeatMode.one) {
      await seek(Duration.zero);
      await play();
    } else if (_nextIndex != null) {
      await skipToNext();
    } else if (_repeat == AudioServiceRepeatMode.all && _tracks.isNotEmpty) {
      await skipToQueueItem(playOrder.first);
    } else {
      await pause();
    }
  }

  Future<void> setLoudnessEnabled(bool enabled) async {
    _loudness = enabled;
    await _applyLoudness();
  }

  Future<void> setVolume(double volume) async {
    _volume = volume;
    await _applyLoudness();
  }

  Future<void> _applyLoudness() async {
    if (_engine == null) return;
    final gain = _loudness ? _gain : 0.0;
    if (_enhancer != null) {
      final level = musicVolume(gain, volume: _volume);
      // ExoPlayer's volume stops at 1. Positive gain goes through its DSP.
      await _player.setVolume(level.clamp(0.0, 1.0));
      await _enhancer!.setEnabled(level > 1);
      if (level > 1) {
        await _enhancer!.setTargetGain(20 * math.log(level) / math.ln10);
      }
    } else {
      await _player.setVolume(musicVolume(gain, volume: _volume));
    }
  }

  @override
  Future<void> play() async {
    if (current == null || _loading) return;
    if (_engine == null ||
        _player.processingState == audio.ProcessingState.idle) {
      await _load();
      return;
    }
    if (_player.processingState == audio.ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    unawaited(
      _player.play().catchError((Object _) {
        if (!_loading) unawaited(_recover());
      }),
    );
  }

  @override
  Future<void> pause() async {
    await _engine?.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    await _engine?.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    if (_nextIndex case final next?) {
      await skipToQueueItem(next);
    } else if (_repeat == AudioServiceRepeatMode.all && _tracks.isNotEmpty) {
      await skipToQueueItem(playOrder.first);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
    } else {
      final order = playOrder;
      final at = order.indexOf(_index);
      if (at > 0) await skipToQueueItem(order[at - 1]);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _tracks.length) return;
    _index = index;
    await _load();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _repeat = repeatMode;
    _publish();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode != AudioServiceShuffleMode.none;
    if (_shuffled == enabled) return;
    _shuffled = enabled;
    if (enabled) _shuffleOrder();
    _publish();
  }

  @override
  Future<void> stop() async {
    _generation++;
    _loading = false;
    await _engine?.stop();
    await super.stop();
    _publish();
  }

  MediaItem _media(MusicTrack track) => MediaItem(
    id: track.id,
    title: track.title,
    artist: track.singers,
    album: track.dateLabel,
    duration: track.duration,
    displaySubtitle: '${track.singers} · ${track.dateLabel}',
  );
  void _publishQueue() {
    queue.add(_tracks.map(_media).toList());
    _publish();
  }

  void _publish() {
    if (_disposed) return;
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.setShuffleMode,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _loading
            ? AudioProcessingState.loading
            : switch (_engine?.processingState ?? audio.ProcessingState.idle) {
                audio.ProcessingState.idle => AudioProcessingState.idle,
                audio.ProcessingState.loading => AudioProcessingState.loading,
                audio.ProcessingState.buffering =>
                  AudioProcessingState.buffering,
                audio.ProcessingState.ready => AudioProcessingState.ready,
                audio.ProcessingState.completed =>
                  AudioProcessingState.completed,
              },
        playing: playing,
        updatePosition: position,
        bufferedPosition: _engine?.bufferedPosition ?? Duration.zero,
        repeatMode: _repeat,
        shuffleMode: _shuffled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        queueIndex: _index < 0 ? null : _index,
      ),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_engine?.dispose());
    super.dispose();
  }
}

enum _Open { playing, unavailable, failed }
