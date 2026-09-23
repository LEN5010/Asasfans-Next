import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/dynamic_novel_repository.dart';
import '../domain/novel_repository.dart';
import 'novel_feed_controller.dart';

final novelRepositoryProvider = Provider<NovelRepository>(
  (ref) => DynamicNovelRepository(
    ref.watch(publicApiClientProvider),
    baseUrl: ref.watch(appEnvironmentProvider).dynamicApiBaseUrl,
  ),
);

/// Kept alive with the content page so switching channels keeps loaded pages.
final novelFeedControllerProvider = Provider.autoDispose<NovelFeedController>((
  ref,
) {
  final controller = NovelFeedController(ref.watch(novelRepositoryProvider));
  ref.onDispose(controller.dispose);
  ref.keepAlive();
  return controller;
});

/// Archive-wide rating counts for the filter chips. A failure only hides the
/// counts; it never blocks the list.
final novelFacetsProvider = FutureProvider.autoDispose<NovelFacets>(
  (ref) => ref.watch(novelRepositoryProvider).facets(),
);

/// One work by Douban topic id, cancelled when the reader closes.
final novelDetailProvider = FutureProvider.autoDispose
    .family<NovelDetail, String>((ref, sourceTid) {
      final cancellation = RequestCancellation();
      ref.onDispose(cancellation.cancel);
      return ref
          .watch(novelRepositoryProvider)
          .detail(sourceTid, cancellation: cancellation);
    });
