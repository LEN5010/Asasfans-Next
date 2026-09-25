import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/app/providers.dart';
import 'package:asasfans_next/core/platform/external_link_service.dart';
import 'package:asasfans_next/features/content/application/content_providers.dart';
import 'package:asasfans_next/features/content/domain/community_video_repository.dart';
import 'package:asasfans_next/features/content/domain/dynamic_repository.dart';
import 'package:asasfans_next/features/content/domain/saved_channel.dart';
import 'package:asasfans_next/features/content/presentation/content_page.dart';
import 'package:asasfans_next/features/handoff/application/handoff_providers.dart';
import 'package:asasfans_next/features/handoff/data/sqlite_return_store.dart';
import 'package:asasfans_next/features/handoff/domain/return_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/library_fixture.dart';
import '../helpers/sqlite_fixture.dart';

ContentIdentity _video(int i) =>
    ContentIdentity(source: ContentSource.bilibiliVideo, value: 'BV$i');
ContentIdentity _dynamic(int i) =>
    ContentIdentity(source: ContentSource.bilibiliDynamic, value: '$i');

class _Videos implements CommunityVideoRepository {
  final queries = <CommunityVideoQuery>[];
  @override
  Future<CommunityVideoPage> videos({
    CommunityVideoQuery query = const CommunityVideoQuery(),
    int page = 1,
    RequestCancellation? cancellation,
  }) async {
    queries.add(query);
    return CommunityVideoPage(
      page: page,
      hasMore: false,
      videos: [
        // Channel alternatives are merged by the pager; one tag answers.
        if (query.tags.isEmpty || query.tags.single == '切片')
          for (var i = 0; i < 48; i++)
            CommunityVideo(
              identity: _video(i),
              title: '视频 $i',
              creatorId: '1',
              creatorName: '作者',
              publishedAt: DateTime.utc(
                2026,
                1,
                1,
              ).subtract(Duration(hours: i)),
              rankScore: 1,
            ),
      ],
    );
  }
}

class _Dynamics implements DynamicRepository {
  final queries = <DynamicQuery>[];
  @override
  Future<DynamicPage> search({
    DynamicQuery query = const DynamicQuery(),
    String? cursor,
    RequestCancellation? cancellation,
  }) async {
    queries.add(query);
    return DynamicPage(
      items: [
        for (var i = 0; i < 40; i++)
          DynamicPost(
            identity: _dynamic(i),
            member: const DynamicMember(id: 'uid:1', name: '嘉然今天吃什么'),
            type: DynamicType.text,
            text: '动态 $i',
            images: const [],
            publishedAt: DateTime.utc(2021, 8, 15, 20),
            sourceUrl: Uri.https('t.bilibili.com', '/$i'),
          ),
      ],
    );
  }

  @override
  Future<List<DynamicPost>> onThisDay({
    String? monthDay,
    OnThisDaySort sort = OnThisDaySort.hot,
    int limit = 8,
  }) async => const [];

  @override
  Future<List<DynamicMember>> members() async => const [];
}

class _Links implements ExternalLinkService {
  final opened = <Uri>[];
  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}

void main() {
  late MemoryLocalDatabase db;
  late SqliteReturnStore store;
  setUp(() {
    db = MemoryLocalDatabase();
    store = SqliteReturnStore(db);
  });
  tearDown(() => db.close());

  bool onScreen(WidgetTester tester, String text) {
    final finder = find.text(text);
    if (finder.evaluate().isEmpty) return false;
    final rect = tester.getRect(finder.first);
    final view = Offset.zero & tester.view.physicalSize;
    return rect.overlaps(view.deflate(1)) && rect.top > 60;
  }

  Future<void> pump(WidgetTester tester, Widget page, List<Override> extra) {
    tester.view
      ..physicalSize = const Size(1000, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...offlineLibrary(),
          returnStoreProvider.overrideWithValue(store),
          externalLinkServiceProvider.overrideWithValue(_Links()),
          ...extra,
        ],
        child: MaterialApp(home: page),
      ),
    );
  }

  testWidgets('a video return restores order, window and the card', (
    tester,
  ) async {
    final videos = _Videos();
    await store.save(
      ReturnContext(
        sessionId: 's',
        target: ReturnTarget.contentChannel,
        channel: 'clips',
        createdAt: DateTime.utc(2026, 9, 22),
        query: const {'order': 'score', 'withinDays': 7},
        anchor: ReturnAnchor(identity: _video(40), offset: 0),
      ),
    );
    await pump(
      tester,
      const ContentPage(channel: 'videos', videoKind: 'clips'),
      [communityVideoRepositoryProvider.overrideWithValue(videos)],
    );
    await tester.pumpAndSettle();
    expect(videos.queries.last.order, CommunityVideoOrder.score);
    expect(videos.queries.last.withinDays, 7);
    expect(onScreen(tester, '视频 40'), isTrue);
    expect(onScreen(tester, '视频 0'), isFalse);
  });

  testWidgets('a video session for another kind leaves this one alone', (
    tester,
  ) async {
    final videos = _Videos();
    await store.save(
      ReturnContext(
        sessionId: 's',
        target: ReturnTarget.contentChannel,
        channel: 'replays',
        createdAt: DateTime.utc(2026, 9, 22),
        query: const {'order': 'score'},
      ),
    );
    await pump(
      tester,
      const ContentPage(channel: 'videos', videoKind: 'clips'),
      [communityVideoRepositoryProvider.overrideWithValue(videos)],
    );
    await tester.pumpAndSettle();
    expect(
      videos.queries.every((q) => q.order == CommunityVideoOrder.newest),
      isTrue,
    );
  });

  testWidgets('a dynamics return restores its query and the post', (
    tester,
  ) async {
    final dynamics = _Dynamics();
    await store.save(
      ReturnContext(
        sessionId: 's',
        target: ReturnTarget.contentChannel,
        channel: 'dynamics',
        createdAt: DateTime.utc(2026, 9, 22),
        query: ChannelSpec.ofDynamic(const DynamicQuery(keyword: '生日')).values,
        anchor: ReturnAnchor(identity: _dynamic(30)),
      ),
    );
    await pump(tester, const ContentPage(channel: 'dynamics'), [
      dynamicRepositoryProvider.overrideWithValue(dynamics),
    ]);
    await tester.pumpAndSettle();
    expect(dynamics.queries.last.keyword, '生日');
    expect(onScreen(tester, '动态 30'), isTrue);
  });

  testWidgets('leaving from a dynamic records its query and anchor', (
    tester,
  ) async {
    final dynamics = _Dynamics();
    await pump(tester, const ContentPage(channel: 'dynamics'), [
      dynamicRepositoryProvider.overrideWithValue(dynamics),
    ]);
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ContentPage)),
    );
    await container
        .read(dynamicFeedControllerProvider)
        .applyQuery(const DynamicQuery(keyword: '唱歌'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看原动态 ↗').first);
    await tester.pumpAndSettle();
    final saved = await store.read();
    expect(saved?.channel, 'dynamics');
    expect(saved?.query?['keyword'], '唱歌');
    expect(saved?.anchor?.identity, _dynamic(0));
  });
}
