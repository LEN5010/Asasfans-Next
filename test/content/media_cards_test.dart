import 'package:asasfans_next/app/theme/app_theme.dart';
import 'package:asasfans_next/app/theme/app_tokens.dart';
import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/features/content/domain/community_video_repository.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/features/content/presentation/video_card.dart';
import 'package:asasfans_next/features/content/presentation/fanart_card.dart';
import 'package:asasfans_next/shared/widgets/media_cover.dart';
import 'package:asasfans_next/shared/widgets/media_image_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/image_fixture.dart';

FanartItem _item(FanartContentType type, {List<Uri> images = const []}) =>
    FanartItem(
      identity: const ContentIdentity(
        source: ContentSource.bilibiliDynamic,
        value: '1',
      ),
      text: '真实内容很长，用来检查标题的两行与纯文字摘录。' * 8,
      authorName: '作者',
      authorUid: '1',
      images: images,
      kind: FanartKind.fanart,
      contentType: type,
      category: FanartCategory.normal,
      characterTags: const [],
    );

void main() {
  for (final scale in [1.0, 2.0]) {
    for (final type in [
      FanartContentType.image,
      FanartContentType.video,
      FanartContentType.text,
    ]) {
      testWidgets('UX3: $type uses aligned previews at text scale $scale', (
        tester,
      ) async {
        final uri = Uri.parse('https://fixture.test/cover');
        await cacheImageFixture(
          tester,
          uri,
          // A 240-wide card at the test view's ratio of 3.
          provider: MediaImagePolicy.preview(
            uri,
            logicalWidth: 240,
            devicePixelRatio: 3,
          ),
        );
        final item = _item(
          type,
          images: type == FanartContentType.text ? [] : [uri, uri],
        );
        final scaler = TextScaler.linear(scale);
        final height = FanartCard.extentFor(item, 240, scaler);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: MediaQuery(
              data: MediaQueryData(textScaler: scaler),
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 240,
                    height: height,
                    child: FanartCard(item: item),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (type == FanartContentType.text) {
          expect(find.byType(MediaCover), findsNothing);
          expect(find.byType(Image), findsNothing);
        } else {
          final rect = tester.getSize(find.byType(MediaCover));
          // An image work has the stable portrait box; a video work keeps
          // its whole 16:9 cover. Both fill the one extent a grid of mixed
          // works shares (the pumped height, with no overflow above).
          expect(
            rect.width / rect.height,
            closeTo(
              type == FanartContentType.video
                  ? FanartCard.videoRatio
                  : AppTokens.artworkRatio,
              .001,
            ),
          );
          expect(
            find.text(type == FanartContentType.image ? '2 张' : '去 B 站看 ↗'),
            findsOneWidget,
          );
        }
      });
    }
  }

  testWidgets('indexed videos show real duration but omit absent metrics', (
    tester,
  ) async {
    final uri = Uri.parse('https://fixture.test/video');
    await cacheImageFixture(tester, uri, cacheWidth: 800);
    // Seeded for whichever width the card lays out at.
    for (final width in MediaImagePolicy.buckets) {
      await cacheImageFixture(
        tester,
        uri,
        provider: ResizeImage(
          NetworkImage(uri.toString()),
          width: width,
          height: MediaImagePolicy.maxPixels ~/ width,
          policy: ResizeImagePolicy.fit,
        ),
      );
    }
    final video = CommunityVideo(
      identity: const ContentIdentity(
        source: ContentSource.bilibiliVideo,
        value: 'BVfixture',
      ),
      title: '视频标题',
      creatorName: '',
      creatorId: '1',
      coverUrl: uri,
      duration: const Duration(hours: 1, minutes: 2, seconds: 3),
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 240,
                height: VideoCard.extentFor(video, 240, TextScaler.noScaling),
                child: VideoCard(video: video),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1:02:03'), findsOneWidget);
    expect(find.text('未知作者'), findsOneWidget);
    expect(find.textContaining('播放'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
