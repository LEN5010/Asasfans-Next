import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/time/shanghai_date_provider.dart';
import '../data/community_video_source.dart';
import '../data/dynamic_fanart_repository.dart';
import '../data/dynamic_post_repository.dart';
import '../domain/community_video_repository.dart';
import '../domain/dynamic_repository.dart';
import '../domain/fanart_repository.dart';
import 'community_feed_controller.dart';
import 'dynamic_feed_controller.dart';
import 'fanart_feed_controller.dart';

final fanartRepositoryProvider = Provider<FanartRepository>(
  (ref) => DynamicFanartRepository(
    ref.watch(publicApiClientProvider),
    baseUrl: ref.watch(appEnvironmentProvider).dynamicApiBaseUrl,
  ),
);

final dynamicRepositoryProvider = Provider<DynamicRepository>(
  (ref) => DynamicPostRepository(
    ref.watch(publicApiClientProvider),
    baseUrl: ref.watch(appEnvironmentProvider).dynamicApiBaseUrl,
  ),
);

/// Historical posts for today's Shanghai month-day.
///
/// Cache by the full Shanghai date. Midnight and resume update the key without
/// refetching on every widget rebuild; a late yesterday response is discarded
/// by Riverpod's provider generation when the dependency changes.
final onThisDayProvider = FutureProvider.autoDispose<List<DynamicPost>>((ref) {
  final day = ref.watch(shanghaiDateProvider);
  final monthDay =
      '${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  return ref
      .watch(dynamicRepositoryProvider)
      .onThisDay(monthDay: monthDay, limit: 12);
});

/// Member ids for the search filter. The server wants `uid:<digits>`, which
/// only this endpoint can supply, so a failure disables the member filter
/// rather than letting the UI invent an id.
final dynamicMembersProvider = FutureProvider<List<DynamicMember>>(
  (ref) => ref.watch(dynamicRepositoryProvider).members(),
);

final dynamicFeedControllerProvider =
    Provider.autoDispose<DynamicFeedController>((ref) {
      final controller = DynamicFeedController(
        ref.watch(dynamicRepositoryProvider),
      );
      ref.onDispose(controller.dispose);
      ref.keepAlive();
      return controller;
    });

/// The community video index lives on a different host from the metadata API,
/// so it gets its own client rather than borrowing that base URL.
final communityDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
      headers: {'Accept': 'application/json'},
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return dio;
});

final communityVideoRepositoryProvider = Provider<CommunityVideoRepository>(
  (ref) => CommunityVideoSource(
    ref.watch(communityDioProvider),
    endpoint: CommunityVideoSource.defaultEndpoint,
  ),
);

final communityFeedControllerProvider = Provider.autoDispose
    .family<CommunityFeedController, CommunityChannel>((ref, channel) {
      final controller = CommunityFeedController(
        ref.watch(communityVideoRepositoryProvider),
        anyTags: channel.tags,
        clock: ref.watch(currentTimeProvider),
      );
      ref.onDispose(controller.dispose);
      ref.keepAlive();
      return controller;
    });

/// Curated fanart, indexed videos and historical posts remain separate sources.
enum ContentChannel {
  fanart('fanart', '二创'),
  latest('latest', '最新视频'),
  subscriptions('subscriptions', '订阅更新'),
  clips('clips', '切片'),
  replays('replays', '录播'),
  dynamics('dynamics', '历史动态');

  const ContentChannel(this.slug, this.label);
  final String slug;
  final String label;

  static ContentChannel? fromSlug(String? slug) =>
      ContentChannel.values.where((c) => c.slug == slug).firstOrNull;

  /// Whether the fanart dataset can currently answer this channel.
  bool get isBackedByFanartApi => this == ContentChannel.fanart;

  /// Whether the historical publishing record answers this channel.
  bool get isBackedByDynamicsApi => this == ContentChannel.dynamics;

  /// Whether the community video index answers this channel.
  bool get isBackedByCommunityApi => communityChannel != null;

  CommunityChannel? get communityChannel => switch (this) {
    ContentChannel.latest => CommunityChannel.latest,
    ContentChannel.clips => CommunityChannel.clips,
    ContentChannel.replays => CommunityChannel.replays,
    _ => null,
  };

  FanartQuery get initialQuery => const FanartQuery();
}

/// One controller per channel, kept alive while the branch is on the stack so
/// scrolling back to a channel preserves its loaded pages.
final fanartFeedControllerProvider = Provider.autoDispose
    .family<FanartFeedController, ContentChannel>((ref, channel) {
      final controller = FanartFeedController(
        ref.watch(fanartRepositoryProvider),
        query: channel.initialQuery,
      );
      ref.onDispose(controller.dispose);
      ref.keepAlive();
      return controller;
    });
