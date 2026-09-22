import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/core/storage/storage_providers.dart';
import 'package:asasfans_next/core/time/shanghai_date_provider.dart';
import 'package:asasfans_next/features/creator/application/creator_providers.dart';
import 'package:asasfans_next/features/library/application/library_providers.dart';
import 'package:asasfans_next/features/library/domain/library_models.dart';
import 'package:asasfans_next/features/updates/application/update_providers.dart';
import 'package:asasfans_next/features/updates/domain/update_event.dart';
import 'package:asasfans_next/features/updates/presentation/updates_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_fixture.dart';
import '../helpers/subscriptions_fixture.dart';

final _now = DateTime.utc(2026, 9, 22, 12);

UpdateEvent _video(int id, {bool read = false, bool archived = false}) {
  final content = ContentIdentity(
    source: ContentSource.bilibiliVideo,
    value: 'BV${id.toString().padLeft(10, '0')}',
  );
  return UpdateEvent(
    id: UpdateIds.subscriptionVideo(content),
    kind: UpdateKind.subscriptionVideo,
    title: '视频 $id',
    subtitle: 'UP 123',
    occurredAt: _now.subtract(Duration(minutes: id)),
    observedAt: _now,
    content: content,
    creator: const LocalSubscription(mid: '123', name: 'UP 123'),
    read: read,
    archived: archived,
  );
}

/// Mounts the page over a real schema and a real repository, so what the widget
/// shows is what the store would actually return.
Future<(MemoryLocalDatabase, UpdateSource)> _pump(
  WidgetTester tester, {
  List<UpdateEvent> seed = const [],
}) async {
  final db = MemoryLocalDatabase();
  final source = UpdateSource();
  addTearDown(db.close);
  final container = ProviderContainer(
    overrides: [
      localDatabaseProvider.overrideWithValue(db),
      creatorRepositoryProvider.overrideWithValue(source),
      currentTimeProvider.overrideWithValue(() => _now),
    ],
  );
  addTearDown(container.dispose);
  final repository = container.read(updateRepositoryProvider);
  if (seed.isNotEmpty) {
    await repository.commit(
      UpdateHarvest(
        events: [for (final event in seed) event],
        cursors: const {},
        failedSources: const {},
      ),
    );
    // Read and archive state is set explicitly: commit deliberately never
    // writes it, so seeding it through commit would silently do nothing.
    for (final event in seed) {
      if (event.read) await repository.markRead([event.id], read: true);
      if (event.archived) {
        await repository.archive([event.id], archived: true);
      }
    }
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: UpdatesPage()),
    ),
  );
  await tester.pumpAndSettle();
  return (db, source);
}

void main() {
  testWidgets('the filters show the slice of the inbox they name', (
    tester,
  ) async {
    await _pump(
      tester,
      seed: [_video(1), _video(2, read: true), _video(3, archived: true)],
    );
    // The inbox holds read and unread alike, but not what was filed away.
    expect(find.text('视频 1'), findsOneWidget);
    expect(find.text('视频 2'), findsOneWidget);
    expect(find.text('视频 3'), findsNothing);

    await tester.tap(find.text('未读'));
    await tester.pumpAndSettle();
    expect(find.text('视频 1'), findsOneWidget);
    expect(find.text('视频 2'), findsNothing);

    await tester.tap(find.text('已归档'));
    await tester.pumpAndSettle();
    expect(find.text('视频 3'), findsOneWidget);
    expect(find.text('视频 1'), findsNothing);
  });

  testWidgets('reading and archiving an entry moves it between filters', (
    tester,
  ) async {
    await _pump(tester, seed: [_video(1)]);
    await tester.tap(find.byTooltip('标记已读'));
    await tester.pumpAndSettle();
    // Still in the inbox, no longer unread.
    expect(find.text('视频 1'), findsOneWidget);
    expect(find.byTooltip('标记未读'), findsOneWidget);

    await tester.tap(find.byTooltip('归档'));
    await tester.pumpAndSettle();
    expect(find.text('视频 1'), findsNothing);
    expect(find.text('收件箱是空的'), findsOneWidget);

    await tester.tap(find.text('已归档'));
    await tester.pumpAndSettle();
    expect(find.text('视频 1'), findsOneWidget);
    // Unarchiving returns it to the inbox rather than marking it unread again.
    await tester.tap(find.byTooltip('移回收件箱'));
    await tester.pumpAndSettle();
    expect(find.text('没有归档的更新'), findsOneWidget);
    await tester.tap(find.text('收件箱'));
    await tester.pumpAndSettle();
    expect(find.text('视频 1'), findsOneWidget);
    expect(find.byTooltip('标记未读'), findsOneWidget);
  });

  testWidgets('marking all read leaves archived entries alone', (tester) async {
    await _pump(
      tester,
      seed: [_video(1), _video(2), _video(3, archived: true)],
    );
    await tester.tap(find.byTooltip('全部标记已读'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('标记未读'), findsNWidgets(2));
    await tester.tap(find.text('已归档'));
    await tester.pumpAndSettle();
    // The archived entry was already dealt with; a bulk read must not reach it.
    expect(find.byTooltip('标记已读'), findsOneWidget);
  });

  testWidgets('a source that could not be read is a gap, not silence', (
    tester,
  ) async {
    final (_, source) = await _pump(tester);
    source.failures['123'] = const ApiFailure(ApiFailureKind.offline);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(UpdatesPage)),
    );
    await container
        .read(libraryRepositoryProvider)
        .subscribe(const LocalSubscription(mid: '123', name: 'UP 123'));
    await container.read(updateControllerProvider).run();
    await tester.pumpAndSettle();
    expect(find.textContaining('没有读取成功'), findsOneWidget);
    expect(find.textContaining('这里显示的不是全部更新'), findsOneWidget);
    // An empty list plus a failed source must not read as "nothing new".
    expect(find.text('收件箱是空的'), findsOneWidget);
  });

  testWidgets('a first pass explains why it produced nothing', (tester) async {
    final (_, source) = await _pump(tester);
    source.rows['123'] = [updateVideo(1), updateVideo(2)];
    final container = ProviderScope.containerOf(
      tester.element(find.byType(UpdatesPage)),
    );
    await container
        .read(libraryRepositoryProvider)
        .subscribe(const LocalSubscription(mid: '123', name: 'UP 123'));
    await container.read(updateControllerProvider).run();
    await tester.pumpAndSettle();
    expect(find.textContaining('新订阅的历史投稿不会补进收件箱'), findsOneWidget);
    expect(find.text('收件箱是空的'), findsOneWidget);
  });
}
