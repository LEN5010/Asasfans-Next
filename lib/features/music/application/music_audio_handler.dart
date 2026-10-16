import 'dart:async';
import 'dart:collection';
import 'dart:io';

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
  int _generation = 0;
  bool _disposed = false;
  String? message;
  AudioServiceRepeatMode _repeat = AudioServiceRepeatMode.none;
  AudioServiceRepeatMode get repeat => _repeat;

  Future<void> _initialize() async {
    try {
      if (Platform.isWindows) {
        JustAudioMediaKit.ensureInitialized(linux: false, windows: true);
      }
      _enhancer = Platform.isAndroid ? audio.AndroidLoudnessEnhancer() : null;
      _engine = audio.AudioPlayer(
        audioPipeline: audio.AudioPipeline(
          androidAudioEffects: [?_enhancer],
        ),
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
      message = '音乐播放初始化失败';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> playTracks(List<MusicTrack> values, {int start = 0}) async {
    if (values.isEmpty) return;
    _tracks = List.of(values);
    _index = start.clamp(0, values.length - 1);
    _publishQueue();
    await _load();
  }

  Future<void> enqueue(MusicTrack track, {bool next = false}) async {
    if (_tracks.isEmpty) {
      await playTracks([track]);
      return;
    }
    if (next) {
      _tracks.insert(_index + 1, track);
    } else {
      _tracks.add(track);
    }
    _publishQueue();
    message = next ? '已设为下一首' : '已加入队列';
    notifyListeners();
  }

  Future<void> removeTrack(int at) async {
    if (at < 0 || at >= _tracks.length) return;
    final wasCurrent = at == _index;
    _tracks.removeAt(at);
    if (_tracks.isEmpty) {
      _index = -1;
      await stop();
      mediaItem.add(null);
    } else if (at < _index) {
      _index--;
    } else if (wasCurrent) {
      if (_index >= _tracks.length) _index = _tracks.length - 1;
      await _load();
    }
    _publishQueue();
  }

  Future<void> _load({
    Duration at = Duration.zero,
    bool retry = false,
    bool resume = true,
  }) async {
    final song = current;
    if (song == null) return;
    final generation = ++_generation;
    _loading = true;
    if (!retry) _retried = false;
    message = null;
    mediaItem.add(_media(song));
    _publish();
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        _ready ??= _initialize();
        await _ready;
        await _engine?.pause();
        if (generation != _generation || _disposed) return;
        await _streams.prefetch(_tracks.skip(_index).take(3).map((s) => s.id));
        final stream = await _streams.resolve(song.id);
        if (stream == null) throw const FormatException('这首暂时无法播放');
        if (generation != _generation || _disposed) return;
        _gain = stream.gain;
        await _player.setUrl(stream.uri.toString(), initialPosition: at);
        if (generation != _generation || _disposed) return;
        await _applyLoudness();
        _loading = false;
        if (resume) {
          unawaited(
            _player.play().catchError((Object _) {
              if (!_loading) unawaited(_recover());
            }),
          );
        }
        _publish();
        return;
      } on Object {
        if (generation != _generation || _disposed) return;
        _streams.invalidate(song.id);
        if (message == '音乐播放初始化失败') {
          _loading = false;
          _publish();
          return;
        }
        if (attempt == 0) continue;
      }
    }
    _loading = false;
    message = '「${song.title}」暂时无法播放';
    notifyListeners();
    // Move forward only, so an unavailable queue cannot loop forever.
    if (_index + 1 < _tracks.length) {
      final failure = message;
      _index++;
      await _load();
      message = failure;
      notifyListeners();
    } else {
      await _engine?.stop();
      _publish();
    }
  }

  Future<void> _recover() async {
    if (_recovering || current == null) return;
    _recovering = true;
    try {
      if (_retried) {
        message = '「${current!.title}」暂时无法播放';
        if (_index + 1 < _tracks.length) {
          _index++;
          await _load();
        } else {
          await _engine?.stop();
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
    } else if (_index + 1 < _tracks.length) {
      await skipToNext();
    } else if (_repeat == AudioServiceRepeatMode.all && _tracks.isNotEmpty) {
      await skipToQueueItem(0);
    } else {
      await pause();
    }
  }

  Future<void> setLoudnessEnabled(bool enabled) async {
    _loudness = enabled;
    await _applyLoudness();
  }

  Future<void> _applyLoudness() async {
    if (_engine == null) return;
    await _player.setVolume(_loudness ? musicVolume(_gain) : 1);
    if (_enhancer != null) {
      await _enhancer!.setEnabled(_loudness && _gain > 0);
      if (_loudness && _gain > 0) await _enhancer!.setTargetGain(_gain);
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
    if (_index + 1 < _tracks.length) {
      _index++;
      await _load();
    } else if (_repeat == AudioServiceRepeatMode.all) {
      await skipToQueueItem(0);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
    } else if (_index > 0) {
      _index--;
      await _load();
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
  Future<void> stop() async {
    _generation++;
    _loading = false;
    await _engine?.stop();
    await super.stop();
    _publish();
  }

  void clearMessage() {
    message = null;
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
    notifyListeners();
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
