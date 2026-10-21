import 'package:asasfans_next/app/asasfans_app.dart';
import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/features/handoff/application/handoff_providers.dart';
import 'package:asasfans_next/features/handoff/data/sqlite_return_store.dart';
import 'package:asasfans_next/features/handoff/domain/return_context.dart';
import 'package:asasfans_next/features/operations/data/collection_repository.dart';
import 'package:asasfans_next/features/operations/domain/fanart_collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_fixture.dart';
import '../helpers/today_fixture.dart';

const _video = ContentIdentity(
  source: ContentSource.bilibiliVideo,
  value: 'BV1xx411c7mD',
);

void main() {
  late MemoryLocalDatabase db;
  late SqliteReturnStore store;
  setUp(() {
    db = MemoryLocalDatabase();
    store = SqliteReturnStore(db);
  });
  tearDown(() => db.close());

  /// A session written before the app starts, standing in for the process
  /// having been reclaimed while Bilibili was in the foreground.
  Future<void> seed({
    required ReturnTarget target,
    String? channel,
    bool consumed = false,
    Map<String, Object?> query = const {'keyword': '生日'},
  }) => store.save(
    ReturnContext(
      sessionId: 'session-1',
      target: target,
      channel: channel,
      createdAt: DateTime.utc(2026, 9, 22),
      query: query,
      anchor: const ReturnAnchor(identity: _video, offset: 900),
      openedContent: _video,
      consumed: consumed,
    ),
  );

  Future<void> start(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    tester.view
      ..physicalSize = const Size(1280, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...offlineTodayOverrides(),
          returnStoreProvider.overrideWithValue(store),
          ...overrides,
        ],
        child: const AsasfansApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a cold start returns to the channel that was being picked from',
    (tester) async {
      await seed(target: ReturnTarget.contentChannel, channel: 'clips');
      await start(tester);
      expect(
        find.text('切片'),
        findsWidgets,
        reason: 'the stored channel, not the default landing page',
      );
      expect(find.byTooltip('刷新今日'), findsNothing);
    },
  );

  testWidgets('the session is consumed, so a restart does not replay it', (
    tester,
  ) async {
    await seed(target: ReturnTarget.contentChannel, channel: 'clips');
    await start(tester);
    final after = await store.read();
    expect(after, isNotNull);
    expect(
      after!.consumed,
      isTrue,
      reason: 'a repeated cold start must not navigate again',
    );
  });

  testWidgets(
    'a cold collection return keeps Today underneath and consumes its session',
    (tester) async {
      const id = 'cijian-gongming-2026';
      await seed(
        target: ReturnTarget.contentChannel,
        channel: 'fanart',
        query: const {'collectionId': id},
      );
      await start(
        tester,
        overrides: [
          collectionProvider(id).overrideWith(
            (ref) async => FanartCollection(
              id: id,
              title: '此间共鸣 · 2026 线下物料',
              dates: '2026.10.24 — 10.25',
              venue: '上海',
              sourceUrl: Uri.parse('https://www.bilibili.com/opus/123'),
              sourceAuthor: '一个魂儿周报',
              groups: const [],
              entries: const [],
            ),
          ),
        ],
      );
      expect(find.text('此间共鸣 · 2026 线下物料'), findsOneWidget);
      expect((await store.read())!.consumed, isTrue);
      expect(find.byTooltip('返回'), findsOneWidget);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.text('此间共鸣 · 2026 线下物料'), findsNothing);
      expect(find.byTooltip('刷新今日'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an already-consumed session leaves the landing page alone', (
    tester,
  ) async {
    await seed(
      target: ReturnTarget.contentChannel,
      channel: 'clips',
      consumed: true,
    );
    await start(tester);
    expect(
      find.byTooltip('刷新今日'),
      findsOneWidget,
      reason: 'a used session is not a pending return',
    );
  });

  testWidgets('no session at all starts on Today as usual', (tester) async {
    await start(tester);
    expect(find.byTooltip('刷新今日'), findsOneWidget);
  });

  testWidgets('a library target returns to the personal area', (tester) async {
    await seed(target: ReturnTarget.library);
    await start(tester);
    expect(find.byTooltip('刷新今日'), findsNothing);
    expect(find.text('备份与恢复'), findsWidgets);
  });

  testWidgets('a today target stays on Today rather than failing', (
    tester,
  ) async {
    await seed(target: ReturnTarget.today);
    await start(tester);
    expect(find.byTooltip('刷新今日'), findsOneWidget);
  });

  testWidgets('an unknown stored channel lands on the channel list', (
    tester,
  ) async {
    // A renamed or corrupted slug must not compose a broken route.
    await seed(
      target: ReturnTarget.contentChannel,
      channel: 'a-channel-that-no-longer-exists',
    );
    await start(tester);
    expect(find.byTooltip('刷新今日'), findsNothing);
    expect(
      find.text('二创'),
      findsWidgets,
      reason: 'falls back to the default channel, not an error page',
    );
    expect(find.text('页面不存在'), findsNothing);
  });

  testWidgets('a restore never hands the video back to Bilibili', (
    tester,
  ) async {
    await seed(target: ReturnTarget.contentChannel, channel: 'clips');
    await start(tester);
    // The stored opened item is remembered for context, but coming back must
    // not bounce the user straight out again.
    final consumed = await store.read();
    expect(consumed!.openedContent, _video);
    expect(find.text('切片'), findsWidgets);
  });
}
