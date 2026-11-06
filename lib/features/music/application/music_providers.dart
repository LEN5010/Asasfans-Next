import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../../../core/config/app_version.dart';
import '../../../core/storage/storage_providers.dart';
import '../../preferences/application/preferences_controller.dart';
import '../data/music_catalog_repository.dart';
import '../data/music_download_store.dart';
import '../data/music_stream_repository.dart';
import 'music_audio_handler.dart';
import 'music_downloads.dart';

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
final musicStreamRepositoryProvider = Provider(
  (ref) => MusicStreamRepository(ref.watch(musicDioProvider)),
);

/// Saved songs live beside the personal database, outside it and backups.
final musicDownloadsProvider = ChangeNotifierProvider<MusicDownloads>((ref) {
  final downloads = MusicDownloads(
    MusicDownloadStore(
      ref.watch(musicDioProvider),
      () async => Directory(
        path.join(path.dirname(await resolvePersonalDatabasePath()), 'music'),
      ),
    ),
    ref.watch(musicStreamRepositoryProvider),
  );
  unawaited(downloads.load());
  return downloads;
});
final musicMoreMembersProvider = StateProvider<bool>((ref) => false);

final musicAudioHandlerProvider = ChangeNotifierProvider<MusicAudioHandler>((
  ref,
) {
  final downloads = ref.read(musicDownloadsProvider);
  final handler = MusicAudioHandler(
    ref.read(musicStreamRepositoryProvider),
    offline: downloads.of,
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
