import 'dart:async';
import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/core/storage/storage_failure.dart';
import 'package:asasfans_next/features/creator/domain/creator_repository.dart';
import 'package:asasfans_next/features/library/domain/library_models.dart';
import 'package:asasfans_next/features/subscriptions/domain/subscription_updates.dart';

VideoSummary updateVideo(
  int id, {
  int? seconds,
  String mid = '123',
  String? title,
}) => VideoSummary(
  identity: ContentIdentity(
    source: ContentSource.bilibiliVideo,
    value: 'BV${id.toString().padLeft(10, '0')}',
  ),
  title: title ?? '更新 $id',
  creatorId: mid,
  creatorName: '作者 $mid',
  publishedAt: DateTime.fromMillisecondsSinceEpoch(
    (seconds ?? 100000 - id) * 1000,
    isUtc: true,
  ),
);
SubscriptionRoster updateRoster(List<String> mids, {int revision = 0}) =>
    SubscriptionRoster(
      storeId: 'fixture',
      revision: revision,
      creators: [
        for (final mid in mids) LocalSubscription(mid: mid, name: 'UP $mid'),
      ],
    );

class UpdateSource implements CreatorRepository {
  final rows = <String, List<VideoSummary>>{};
  final failures = <String, Object>{};
  final calls = <(String, int)>[];
  Future<CreatorArchivePage> Function(
    CreatorArchiveQuery,
    int,
    RequestCancellation?,
  )?
  handler;
  @override
  Future<CreatorProfile> profile(
    String mid, {
    RequestCancellation? cancellation,
  }) async => CreatorProfile(mid: mid, name: 'UP $mid');
  @override
  Future<CreatorArchivePage> archives(
    CreatorArchiveQuery query, {
    int page = 1,
    RequestCancellation? cancellation,
  }) async {
    calls.add((query.mid, page));
    if (handler != null) return handler!(query, page, cancellation);
    if (failures[query.mid] != null) throw failures[query.mid]!;
    return pageFor(query.mid, page);
  }

  CreatorArchivePage pageFor(String mid, int page) {
    final items = rows[mid] ?? [];
    return CreatorArchivePage(
      items: items.skip((page - 1) * 30).take(30).toList(),
      page: page,
      total: items.length,
      hasMore: page * 30 < items.length,
    );
  }
}

class MemoryUpdateStore implements SubscriptionUpdateStore {
  MemoryUpdateStore(List<String> mids) : snapshot = updateRoster(mids);
  SubscriptionRoster snapshot;
  final reads = <String, bool>{};
  final events = StreamController<int>.broadcast();
  int changesCount = 0;
  StorageFailure? readFailure;
  StorageFailure? writeFailure;
  Future<void> Function()? beforeCheck;
  @override
  Stream<int> get changes => events.stream;
  @override
  Future<SubscriptionRoster> roster() async => snapshot;
  @override
  Future<void> checkRoster(SubscriptionRoster roster) async {
    await beforeCheck?.call();
    if (roster.revision != snapshot.revision ||
        roster.storeId != snapshot.storeId) {
      throw const StorageFailure(StorageFailureKind.changed);
    }
  }

  @override
  Future<Map<String, bool>> readStates(Iterable<String> bvids) async {
    if (readFailure != null) throw readFailure!;
    return {
      for (final id in bvids)
        if (reads.containsKey(id)) id: reads[id]!,
    };
  }

  @override
  Future<void> mark(Iterable<String> bvids, {required bool read}) async {
    if (writeFailure != null) throw writeFailure!;
    for (final id in bvids) {
      reads[id] = read;
    }
    events.add(++changesCount);
  }

  @override
  Future<void> close() => events.close();
}
