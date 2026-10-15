import '../helpers/library_fixture.dart';
import 'dart:async';

import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/core/time/shanghai_date_provider.dart';
import 'package:asasfans_next/features/calendar/application/calendar_providers.dart';
import 'package:asasfans_next/features/calendar/domain/calendar_event.dart';
import 'package:asasfans_next/features/content/application/content_providers.dart';
import 'package:asasfans_next/features/content/domain/community_video_repository.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/features/today/application/today_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fanart implements FanartRepository {
  final queries = <FanartQuery>[];
  final handles = <RequestCancellation>[];
  final pending = <Completer<FanartPage>>[];
  @override
  Future<FanartPage> page({
    FanartQuery query = const FanartQuery(),
    String? cursor,
    RequestCancellation? cancellation,
  }) {
    queries.add(query);
    handles.add(cancellation!);
    final completer = Completer<FanartPage>();
    pending.add(completer);
    return completer.future;
  }

  @override
  Future<List<FanartItem>> sample({
    FanartQuery query = const FanartQuery(),
    RequestCancellation? cancellation,
  }) async => (await page(query: query, cancellation: cancellation)).items;
}

class _Community implements CommunityVideoRepository {
  final queries = <CommunityVideoQuery>[];
  final handles = <RequestCancellation>[];
  @override
  Future<CommunityVideoPage> videos({
    CommunityVideoQuery query = const CommunityVideoQuery(),
    int page = 1,
    RequestCancellation? cancellation,
  }) async {
    queries.add(query);
    handles.add(cancellation!);
    return CommunityVideoPage(
      videos: [
        CommunityVideo(
          identity: const ContentIdentity(
            source: ContentSource.bilibiliVideo,
            value: 'same',
          ),
          title: '同时具有多个切片标签',
          creatorName: '作者',
          creatorId: '1',
          publishedAt: DateTime.utc(2026, 9, 20),
        ),
      ],
      page: page,
      hasMore: false,
    );
  }
}

class _Calendar implements CalendarRepository {
  int calls = 0;
  @override
  Future<CalendarSnapshot> events({
    required DateTime from,
    required DateTime until,
    bool forceRefresh = false,
  }) async {
    calls++;
    return CalendarSnapshot(
      events: const [],
      fetchedAt: DateTime.utc(2026, 9, 21, 4),
    );
  }
}

void main() {
  testWidgets(
    'today shares the current monthly calendar request with the calendar page',
    (tester) async {
      final repository = _Calendar();
      final container = ProviderContainer(
        overrides: [
          ...offlineLibrary(),
          currentTimeProvider.overrideWithValue(
            () => DateTime.utc(2026, 9, 21, 4),
          ),
          calendarRepositoryProvider.overrideWithValue(repository),
        ],
      );
      container.listen(todayScheduleProvider, (_, _) {});
      container.listen(monthEventsProvider(DateTime.utc(2026, 9)), (_, _) {});
      await tester.pump();
      expect(repository.calls, 1);
      expect(container.read(todayScheduleProvider).hasValue, isTrue);
      // Dispose inside the body: the day clock arms a timer until the next
      // Shanghai midnight, and addTearDown runs after the binding has already
      // checked for pending timers.
      container.dispose();
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'today clips use three OR lanes and show one deduplicated result',
    (tester) async {
      final repository = _Community();
      final now = DateTime.utc(2026, 9, 21, 4);
      final container = ProviderContainer(
        overrides: [
          ...offlineLibrary(),
          currentTimeProvider.overrideWithValue(() => now),
          communityVideoRepositoryProvider.overrideWithValue(repository),
        ],
      );
      container.listen(todayClipsProvider, (_, _) {});
      await tester.pump();
      expect(
        repository.queries.map((query) => query.tags.single).toSet(),
        CommunityChannel.clips.tags.toSet(),
      );
      expect(
        repository.queries.every(
          (query) =>
              query.asOf == now && query.order == CommunityVideoOrder.newest,
        ),
        isTrue,
      );
      expect(container.read(todayClipsProvider).requireValue, hasLength(1));
      // See above: the armed day timer outlives addTearDown.
      container.dispose();
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'a new draw cancels the last one and a late response cannot replace it',
    (tester) async {
      final repository = _Fanart();
      final container = ProviderContainer(
        overrides: [
          ...offlineLibrary(),
          currentTimeProvider.overrideWithValue(
            () => DateTime.utc(2026, 9, 21, 4),
          ),
          fanartRepositoryProvider.overrideWithValue(repository),
        ],
      );
      final subscription = container.listen(todayFanartProvider, (_, _) {});
      expect(repository.queries.single.limit, todayFanartCount);
      // 换一批.
      container.invalidate(todayFanartProvider);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(repository.handles.first.isCancelled, isTrue);
      expect(repository.pending, hasLength(2));
      repository.pending.last.complete(
        const FanartPage(items: [], snapshotId: 'today'),
      );
      await tester.pump(const Duration(milliseconds: 1));
      final current = container.read(todayFanartProvider);
      repository.pending.first.completeError(StateError('old response'));
      await tester.pump(const Duration(milliseconds: 1));
      expect(container.read(todayFanartProvider), current);
      subscription.close();
      container.dispose();
      expect(repository.handles.last.isCancelled, isTrue);
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
}
