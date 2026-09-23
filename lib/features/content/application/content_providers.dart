import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/storage/storage_providers.dart';
import '../../../core/time/shanghai_date_provider.dart';
import '../data/community_video_source.dart';
import '../data/dynamic_fanart_repository.dart';
import '../data/dynamic_post_repository.dart';
import '../data/sqlite_channel_repository.dart';
import '../domain/community_video_repository.dart';
import '../domain/dynamic_repository.dart';
import '../domain/fanart_repository.dart';
import '../domain/saved_channel.dart';
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
final onThisDaySortProvider = StateProvider<OnThisDaySort>(
  (ref) => OnThisDaySort.hot,
);

final onThisDayProvider = FutureProvider.autoDispose<List<DynamicPost>>((ref) {
  final day = ref.watch(shanghaiDateProvider);
  final monthDay =
      '${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  return ref
      .watch(dynamicRepositoryProvider)
      .onThisDay(
        monthDay: monthDay,
        sort: ref.watch(onThisDaySortProvider),
        limit: 12,
      );
});

/// Member ids for the search filter. The server wants `uid:<digits>`, which
/// only this endpoint can supply, so a failure disables the member filter
/// rather than letting the UI invent an id.
final dynamicMembersProvider = FutureProvider<List<DynamicMember>>(
  (ref) => ref.watch(dynamicRepositoryProvider).members(),
);

final savedChannelRepositoryProvider = Provider<SavedChannelRepository>((ref) {
  final repository = SqliteChannelRepository(ref.watch(localDatabaseProvider));
  ref.onDispose(() => unawaited(repository.close()));
  return repository;
});

final savedChannelsProvider = FutureProvider.autoDispose
    .family<List<SavedChannel>, ChannelFeed>((ref, feed) {
      final repository = ref.watch(savedChannelRepositoryProvider);
      // Rebuild after a save, rename or removal so the picker never shows a
      // channel that no longer exists.
      final subscription = repository.changes.listen((_) {
        ref.invalidateSelf();
      });
      ref.onDispose(subscription.cancel);
      return repository.channels(feed: feed);
    });

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

/// The indexed video stream is the main source; fanart, historical posts and
/// novels are the archive.
enum ContentChannel {
  videos('videos', '视频'),
  fanart('fanart', '二创'),
  dynamics('dynamics', '动态'),
  novels('novels', '小说');

  const ContentChannel(this.slug, this.label);
  final String slug;
  final String label;

  /// Earlier slugs from saved returns and links: the video kinds became
  /// filters inside the video channel, and subscriptions were retired.
  static const legacyVideoSlugs = {
    'latest',
    'clips',
    'replays',
    'subscriptions',
  };

  static ContentChannel? fromSlug(String? slug) =>
      ContentChannel.values.where((c) => c.slug == slug).firstOrNull ??
      (legacyVideoSlugs.contains(slug) ? ContentChannel.videos : null);

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
