import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_version.dart';
import '../../preferences/application/preferences_controller.dart';
import '../data/music_catalog_repository.dart';
import '../data/music_stream_repository.dart';
import 'music_audio_handler.dart';

final musicDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'User-Agent': appUserAgent},
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return dio;
});
final musicCatalogRepositoryProvider = Provider(
  (ref) => MusicCatalogRepository(ref.watch(musicDioProvider)),
);
final musicCatalogProvider = FutureProvider<MusicCatalog>(
  (ref) => ref.watch(musicCatalogRepositoryProvider).load(),
);
final musicMoreMembersProvider = StateProvider<bool>((ref) => false);

final musicAudioHandlerProvider = ChangeNotifierProvider<MusicAudioHandler>((
  ref,
) {
  final handler = MusicAudioHandler(
    MusicStreamRepository(ref.read(musicDioProvider)),
  );
  ref.listen(
    preferencesControllerProvider.select((s) => s.values.musicLoudnessEnabled),
    (_, enabled) {
      unawaited(handler.setLoudnessEnabled(enabled));
    },
    fireImmediately: true,
  );
  ref.listen(
    preferencesControllerProvider.select((s) => s.values.musicVolume),
    (_, volume) => unawaited(handler.setVolume(volume)),
    fireImmediately: true,
  );
  return handler;
});
