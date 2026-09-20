import 'dart:async';

import 'package:asasfans_next/core/time/shanghai_date_provider.dart';
import 'package:asasfans_next/features/content/application/content_providers.dart';
import 'package:asasfans_next/features/content/domain/dynamic_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository implements DynamicRepository {
  final days = <String?>[];
  final pending = <Completer<List<DynamicPost>>>[];
  bool delayed = false;
  @override
  Future<List<DynamicPost>> onThisDay({
    String? monthDay,
    OnThisDaySort sort = OnThisDaySort.hot,
    int limit = 8,
  }) {
    days.add(monthDay);
    if (!delayed) return Future.value([]);
    final result = Completer<List<DynamicPost>>();
    pending.add(result);
    return result.future;
  }

  @override
  Future<List<DynamicMember>> members() async => [];
  @override
  Future<DynamicPage> search({
    DynamicQuery query = const DynamicQuery(),
    String? cursor,
    RequestCancellation? cancellation,
  }) async => const DynamicPage(items: []);
}

void main() {
  testWidgets(
    'Shanghai midnight changes the full date key and refetches once, not on every read',
    (tester) async {
      var now = DateTime.utc(2026, 9, 21, 15, 59, 59);
      final repository = _Repository();
      final container = ProviderContainer(
        overrides: [
          currentTimeProvider.overrideWithValue(() => now),
          dynamicRepositoryProvider.overrideWithValue(repository),
        ],
      );
      final sub = container.listen(onThisDayProvider, (_, _) {});
      await tester.pump();
      expect(repository.days, ['09-21']);
      container.read(onThisDayProvider);
      expect(repository.days, hasLength(1));
      now = now.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(container.read(shanghaiDateProvider), DateTime.utc(2026, 9, 22));
      expect(repository.days, ['09-21', '09-22']);
      sub.close();
      container.dispose();
      await tester.pump(const Duration(days: 2));
      expect(repository.days, hasLength(2));
    },
  );

  testWidgets(
    'resume after sleep recomputes the day, including a year boundary',
    (tester) async {
      var now = DateTime.utc(2026, 12, 31, 15);
      final repository = _Repository();
      final container = ProviderContainer(
        overrides: [
          currentTimeProvider.overrideWithValue(() => now),
          dynamicRepositoryProvider.overrideWithValue(repository),
        ],
      );
      final sub = container.listen(onThisDayProvider, (_, _) {});
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = DateTime.utc(2027, 1, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(container.read(shanghaiDateProvider), DateTime.utc(2027, 1, 2));
      expect(repository.days, ['12-31', '01-02']);
      sub.close();
      container.dispose();
    },
  );

  testWidgets('yesterday finishing after rollover does not replace today', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 9, 21, 15, 59, 59);
    final repository = _Repository()..delayed = true;
    final container = ProviderContainer(
      overrides: [
        currentTimeProvider.overrideWithValue(() => now),
        dynamicRepositoryProvider.overrideWithValue(repository),
      ],
    );
    final sub = container.listen(onThisDayProvider, (_, _) {});
    await tester.pump();
    now = now.add(const Duration(seconds: 2));
    container.read(shanghaiDateProvider.notifier).resync();
    await tester.pump();
    repository.pending.last.complete([]);
    await tester.pump();
    final todayValue = container.read(onThisDayProvider);
    repository.pending.first.completeError(Exception('yesterday failed'));
    await tester.pump();
    expect(container.read(onThisDayProvider), todayValue);
    sub.close();
    container.dispose();
  });
}
