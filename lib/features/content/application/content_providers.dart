import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/dynamic_fanart_repository.dart';
import '../data/dynamic_post_repository.dart';
import '../domain/dynamic_repository.dart';
import '../domain/fanart_repository.dart';
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
/// The response changes at most once a day, so it is cached for the session
/// instead of being refetched every time the home page rebuilds.
final onThisDayProvider = FutureProvider<List<DynamicPost>>(
  (ref) => ref.watch(dynamicRepositoryProvider).onThisDay(limit: 12),
);

/// Content channels. Live replays and live clips come from a different source
/// than the curated fanart archive, so only the archive-backed channels are
/// served by this repository; the others stay explicitly pending.
enum ContentChannel {
  fanart('fanart', '二创'),
  clips('clips', '切片'),
  dynamics('dynamics', '历史动态');

  const ContentChannel(this.slug, this.label);
  final String slug;
  final String label;

  static ContentChannel? fromSlug(String? slug) =>
      ContentChannel.values.where((c) => c.slug == slug).firstOrNull;

  /// Whether the fanart dataset can currently answer this channel.
  bool get isBackedByFanartApi => this == ContentChannel.fanart;

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
