import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/features/content/application/content_providers.dart';
import 'package:asasfans_next/features/content/domain/dynamic_repository.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/features/content/presentation/content_page.dart';
import 'package:asasfans_next/features/content/presentation/fanart_detail_page.dart';
import 'package:asasfans_next/features/mine/presentation/mine_page.dart';
import 'package:asasfans_next/features/today/presentation/today_page.dart';
import 'package:asasfans_next/features/tools/presentation/tools_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/library_fixture.dart';
import 'helpers/today_fixture.dart';

/// Window sizes that matter: a large desktop, a short desktop window, a
/// common phone, and the smallest phone still supported.
const _sizes = [
  Size(1600, 1400),
  Size(1000, 700),
  Size(800, 600),
  Size(390, 844),
  Size(320, 568),
];

FanartItem _fanart(String id) => FanartItem(
  identity: ContentIdentity(source: ContentSource.bilibiliDynamic, value: id),
  text: '很长的二创标题，用来检查窄窗口下的换行与截断是否会把卡片撑破 $id',
  authorName: '一个名字也相当长的作者 $id',
  authorUid: '1',
  images: const [],
  kind: FanartKind.fanart,
  contentType: FanartContentType.video,
  category: FanartCategory.amv,
  characterTags: const [FanartCharacter.diana, FanartCharacter.bella],
  viewCount: 123456,
  favoriteCount: 7890,
);

DynamicPost _post(String id) => DynamicPost(
  identity: ContentIdentity(source: ContentSource.bilibiliDynamic, value: id),
  member: const DynamicMember(id: 'uid:1', name: '嘉然今天吃什么'),
  type: DynamicType.text,
  text: '往年的一条很长的动态正文，用来确认窄窗口下不会溢出 $id',
  images: const [],
  publishedAt: DateTime.utc(2021, 8, 15, 20),
);

class _FanartStub implements FanartRepository {
  @override
  Future<FanartPage> page({
    FanartQuery query = const FanartQuery(),
    String? cursor,
    RequestCancellation? cancellation,
  }) async => FanartPage(
    items: [for (var i = 0; i < 8; i++) _fanart('$i')],
    snapshotId: 's',
  );

  @override
  Future<FanartItem?> random({
    FanartQuery query = const FanartQuery(),
    RequestCancellation? cancellation,
  }) async => _fanart('r');
}

class _DynamicStub implements DynamicRepository {
  @override
  Future<DynamicPage> search({
    DynamicQuery query = const DynamicQuery(),
    String? cursor,
    RequestCancellation? cancellation,
  }) async => DynamicPage(items: [for (var i = 0; i < 6; i++) _post('$i')]);

  @override
  Future<List<DynamicPost>> onThisDay({
    String? monthDay,
    OnThisDaySort sort = OnThisDaySort.hot,
    int limit = 8,
  }) async => [for (var i = 0; i < 6; i++) _post('$i')];

  @override
  Future<List<DynamicMember>> members() async => const [];
}

Widget _host(Widget home) => ProviderScope(
  overrides: [
    ...offlineTodayOverrides(fanart: [_fanart('today')]),
    fanartRepositoryProvider.overrideWithValue(_FanartStub()),
    dynamicRepositoryProvider.overrideWithValue(_DynamicStub()),
  ],
  child: MaterialApp.router(
    routerConfig: GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => home)],
    ),
  ),
);

void main() {
  final pages = <String, Widget>{
    '今日': const TodayPage(),
    '内容·二创': const ContentPage(),
    '内容·历史动态': const ContentPage(channel: 'dynamics'),
    '我的': const MinePage(),
    '二创详情': FanartDetailPage(item: _fanart('detail')),
  };

  for (final entry in pages.entries) {
    for (final size in _sizes) {
      testWidgets(
        '${entry.key} fits ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          tester.view
            ..physicalSize = size
            ..devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(_host(entry.value));
          await tester.pumpAndSettle();

          // A RenderFlex overflow is reported as an exception in tests, so an
          // absent exception is the assertion here.
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final size in _sizes) {
    testWidgets('工具抽屉 fits ${size.width.toInt()}x${size.height.toInt()}', (
      tester,
    ) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showToolsSheet(context),
                  child: const Text('打开'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('large text does not break the content grid', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // The content page reads the return session, so it needs a store.
          ...offlineLibrary(),
          fanartRepositoryProvider.overrideWithValue(_FanartStub()),
          dynamicRepositoryProvider.overrideWithValue(_DynamicStub()),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery.withClampedTextScaling(
            minScaleFactor: 1.6,
            maxScaleFactor: 1.6,
            child: child!,
          ),
          home: const ContentPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
