import '../helpers/library_fixture.dart';
import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/features/content/application/content_providers.dart';
import 'package:asasfans_next/features/content/domain/community_video_repository.dart';
import 'package:asasfans_next/features/content/presentation/content_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Source implements CommunityVideoRepository {
  final queries = <CommunityVideoQuery>[];
  @override
  Future<CommunityVideoPage> videos({
    CommunityVideoQuery query = const CommunityVideoQuery(),
    int page = 1,
    RequestCancellation? cancellation,
  }) async {
    queries.add(query);
    final name = query.tags.isEmpty ? '全部投稿' : query.tags.single;
    return CommunityVideoPage(
      page: page,
      hasMore: false,
      videos: [
        CommunityVideo(
          identity: ContentIdentity(
            source: ContentSource.bilibiliVideo,
            value: name,
          ),
          title: '$name 内容',
          creatorId: '1',
          creatorName: '作者',
          publishedAt: DateTime.utc(2026, 1, 1),
          rankScore: 1,
        ),
      ],
    );
  }
}

void main() {
  for (final entry in {
    'latest': <String>[],
    'clips': ['切片', '直播剪辑', '直播切片'],
    'replays': ['直播回放', '直播录像', '录播'],
  }.entries) {
    testWidgets('${entry.key} uses its own indexed-video definition', (
      tester,
    ) async {
      final source = _Source();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...offlineLibrary(),
            communityVideoRepositoryProvider.overrideWithValue(source),
          ],
          child: MaterialApp(
            home: ContentPage(channel: 'videos', videoKind: entry.key),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (entry.value.isEmpty) {
        expect(source.queries.single.tags, isEmpty);
        expect(find.text('全部投稿 内容'), findsOneWidget);
      } else {
        expect(
          source.queries.map((q) => q.tags.single).toSet(),
          entry.value.toSet(),
        );
        for (final tag in entry.value) {
          expect(find.text('$tag 内容'), findsOneWidget);
        }
      }
      expect(source.queries.every((q) => q.asOf != null), isTrue);
      expect(find.byTooltip('随机二创'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'channel-specific controllers retain independent filters and pages',
    (tester) async {
      final source = _Source();
      final container = ProviderContainer(
        overrides: [
          ...offlineLibrary(),
          communityVideoRepositoryProvider.overrideWithValue(source),
        ],
      );
      final latest = container.read(
        communityFeedControllerProvider(CommunityChannel.latest),
      );
      final clips = container.read(
        communityFeedControllerProvider(CommunityChannel.clips),
      );
      await latest.loadInitial();
      await clips.loadInitial();
      await clips.applyQuery(clips.state.query.copyWith(withinDays: 7));
      expect(latest.state.query.withinDays, isNull);
      expect(clips.state.query.withinDays, 7);
      expect(latest.state.videos.single.title, '全部投稿 内容');
      expect(clips.state.videos, hasLength(3));
      container.dispose();
    },
  );
}
