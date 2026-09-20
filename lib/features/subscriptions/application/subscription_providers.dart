import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_providers.dart';
import '../../../core/time/shanghai_date_provider.dart';
import '../../creator/application/creator_providers.dart';
import '../../creator/domain/creator_repository.dart';
import '../../library/application/library_providers.dart';
import '../data/sqlite_subscription_update_store.dart';
import '../domain/subscription_updates.dart';
import 'subscription_feed_controller.dart';
import 'subscription_request_queue.dart';

final subscriptionUpdateStoreProvider = Provider<SubscriptionUpdateStore>((
  ref,
) {
  final store = SqliteSubscriptionUpdateStore(
    ref.watch(localDatabaseProvider),
    clock: ref.watch(currentTimeProvider),
  );
  ref.onDispose(() => unawaited(store.close()));
  return store;
});
final subscriptionArchiveSourceProvider = Provider<CreatorRepository>(
  (ref) => SubscriptionRequestQueue(ref.watch(creatorRepositoryProvider)),
);
final subscriptionFeedControllerProvider =
    ChangeNotifierProvider.autoDispose<SubscriptionFeedController>((ref) {
      final controller = SubscriptionFeedController(
        ref.watch(subscriptionArchiveSourceProvider),
        ref.watch(subscriptionUpdateStoreProvider),
        ref.watch(libraryRepositoryProvider).subscriptionChanges,
      );
      unawaited(controller.refresh());
      return controller;
    });
