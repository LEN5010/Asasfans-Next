import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/bilibili_providers.dart';
import '../../../core/time/shanghai_date_provider.dart';
import '../data/bili_playback_repository.dart';
import '../domain/playback_source.dart';

final playbackRepositoryProvider = Provider<PlaybackRepository>(
  (ref) => BiliPlaybackRepository(
    ref.watch(biliReadGatewayProvider),
    clock: ref.watch(currentTimeProvider),
  ),
);
