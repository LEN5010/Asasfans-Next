import 'package:asasfans_next/app/providers.dart';
import 'package:asasfans_next/core/platform/external_link_service.dart';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/video/application/video_providers.dart';
import 'package:asasfans_next/features/video/presentation/video_detail_page.dart';
import 'package:asasfans_next/features/comments/application/comment_providers.dart';
import 'package:asasfans_next/features/comments/data/bili_comment_repository.dart';
import 'package:asasfans_next/features/content/presentation/video_card.dart';
import 'package:asasfans_next/features/library/application/library_providers.dart';
import 'package:asasfans_next/features/library/domain/library_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/library_fixture.dart';
import '../helpers/video_comment_fixture.dart';

class _Links implements ExternalLinkService {
  final opened = <Uri>[];
  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}

void main() {
  late OfflineVideoRepository videos;
  late OfflineCommentRepository comments;
  late _Links links;
  setUp(() {
    videos = OfflineVideoRepository();
    comments = OfflineCommentRepository();
    links = _Links();
    comments.respond = (query, page, _) async => BiliCommentRepository.decode(
      commentPagePayload(page: page, total: 1, root: query.root),
      query,
      page,
    );
  });
  Widget host({Widget? home, double scale = 1}) => ProviderScope(
    overrides: [
      ...offlineLibrary(),
      videoRepositoryProvider.overrideWithValue(videos),
      commentRepositoryProvider.overrideWithValue(comments),
      externalLinkServiceProvider.overrideWithValue(links),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: home ?? const VideoDetailPage(bvid: fixtureBvid),
    ),
  );
  testWidgets(
    'video card opens native root details, part selection stays local until explicit external play',
    (tester) async {
      final video = videoDetailFixture().video;
      await tester.pumpWidget(
        host(
          home: Scaffold(
            bottomNavigationBar: const Text('底栏'),
            body: Center(
              child: SizedBox(
                width: 300,
                height: VideoCard.extentFor(video, 300, TextScaler.noScaling),
                child: VideoCard(video: video),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text(video.title));
      await tester.pumpAndSettle();
      expect(find.byType(VideoDetailPage), findsOneWidget);
      expect(find.text('底栏'), findsNothing);
      expect(links.opened, isEmpty);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(VideoDetailPage)),
      );
      final library = container.read(libraryRepositoryProvider);
      final records = await library.history();
      expect(records.single.action, HistoryAction.detail);
      final selector = find.textContaining('分 P ·');
      await tester.ensureVisible(selector);
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.text('P2 · 第二部分'));
      await tester.pumpAndSettle();
      expect(links.opened, isEmpty);
      await tester.ensureVisible(find.text('在 B 站播放'));
      await tester.tap(find.text('在 B 站播放'));
      await tester.pumpAndSettle();
      expect(links.opened.single.queryParameters, {'p': '2'});
      expect(
        (await library.history()).any(
          (r) => r.action == HistoryAction.playback,
        ),
        isFalse,
      );
      expect(
        (await library.history()).where(
          (r) => r.action == HistoryAction.external,
        ),
        hasLength(1),
      );
    },
  );
  testWidgets(
    'comment failure keeps video details, retry does not refetch metadata',
    (tester) async {
      comments.respond = (_, _, _) async =>
          throw const ApiFailure(ApiFailureKind.riskControl);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expect(find.text('测试视频标题'), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
      await tester.pumpAndSettle();
      expect(find.textContaining('B 站暂时拦截'), findsOneWidget);
      comments.respond = (query, page, _) async => BiliCommentRepository.decode(
        commentPagePayload(total: 1),
        query,
        page,
      );
      await tester.ensureVisible(find.text('重试'));
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(videos.calls, 1);
      expect(find.text('评论内容 100'), findsOneWidget);
    },
  );
  testWidgets(
    'loading/error metadata does not create history; refresh/rebuild does not count another view',
    (tester) async {
      videos.respond = (_) async =>
          throw const ApiFailure(ApiFailureKind.offline);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(VideoDetailPage)),
      );
      final library = container.read(libraryRepositoryProvider);
      expect(await library.history(), isEmpty);
      expect(comments.calls, isEmpty);
      videos.respond = null;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect((await library.history()).single.visits, 1);
      container.invalidate(videoDetailProvider(fixtureBvid));
      await tester.pumpAndSettle();
      expect((await library.history()).single.visits, 1);
    },
  );
  for (final (size, scale) in [
    (const Size(320, 640), 1.0),
    (const Size(390, 840), 2.0),
    (const Size(1280, 900), 1.0),
  ]) {
    testWidgets(
      'video and comments fit $size / $scale with responsive columns',
      (tester) async {
        tester.view
          ..physicalSize = size
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(host(scale: scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('video-details-column')),
          size.width >= 1100 ? findsOneWidget : findsNothing,
        );
        expect(find.byType(TextField), findsNothing);
        expect(find.text('发表评论'), findsNothing);
      },
    );
  }
}
