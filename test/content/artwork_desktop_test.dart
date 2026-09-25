import '../helpers/library_fixture.dart';
import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/features/content/presentation/fanart_detail_page.dart';
import 'package:asasfans_next/features/content/presentation/fanart_image_viewer.dart';
import 'package:asasfans_next/shared/widgets/media_image_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/image_fixture.dart';

void main() {
  testWidgets('desktop detail uses separate gallery and information columns', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1200, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final uri = Uri.parse('https://fixture.test/detail');
    await cacheImageFixture(tester, uri);
    final item = FanartItem(
      identity: const ContentIdentity(
        source: ContentSource.bilibiliDynamic,
        value: '1',
      ),
      text: '全文内容',
      authorName: '作者',
      authorUid: '1',
      images: [uri],
      kind: FanartKind.fanart,
      contentType: FanartContentType.image,
      category: FanartCategory.normal,
      characterTags: const [],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...offlineLibrary()],
        child: MaterialApp(home: FanartDetailPage(item: item)),
      ),
    );
    await tester.pumpAndSettle();
    final gallery = tester.getRect(
      find.byKey(const ValueKey('fanart-detail-gallery')),
    );
    final info = tester.getRect(
      find.byKey(const ValueKey('fanart-detail-info')),
    );
    expect(gallery.right, lessThanOrEqualTo(info.left));
    expect(info.width, inInclusiveRange(340, 440));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keyboard paging, zoom, long-image reading and Escape work on the root route',
    (tester) async {
      // The viewer derives its decode size from the viewport times the device
      // pixel ratio, so both must be pinned here. Without this the default ratio of 3
      // asked for a 2400-wide decode, missed the seeded 800-wide entry, and the
      // case measured a placeholder instead of the long image.
      tester.view
        ..physicalSize = const Size(800, 600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final images = [
        Uri.parse('https://fixture.test/long'),
        Uri.parse('https://fixture.test/second'),
      ];
      for (final uri in images) {
        await cacheImageFixture(
          tester,
          uri,
          width: 160,
          height: 1600,
          provider: MediaImagePolicy.original(
            uri,
            viewportWidth: 800,
            devicePixelRatio: 1,
          ),
        );
      }
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => FanartImageViewer(images: images),
                  ),
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await tester.pumpAndSettle();
      final viewer = tester.widget<InteractiveViewer>(
        find.byKey(const ValueKey('artwork-zoom-1')),
      );
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        greaterThan(1),
      );
      expect(
        tester.widget<PageView>(find.byType(PageView)).physics,
        isA<NeverScrollableScrollPhysics>(),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
      await tester.pumpAndSettle();
      expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 1);
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(
            find.byKey(const ValueKey('artwork-zoom-1')),
          ),
          scrollDelta: const Offset(0, -100),
          kind: PointerDeviceKind.mouse,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        greaterThan(1),
      );
      await tester.tap(find.byTooltip('长图阅读'));
      await tester.pumpAndSettle();
      final reading = find.byKey(const PageStorageKey('artwork-reading-1'));
      final image = find.descendant(of: reading, matching: find.byType(Image));
      expect(tester.getSize(image).width, 800);
      expect(tester.getSize(image).height, greaterThan(600));
      expect(find.byType(InteractiveViewer), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(FanartImageViewer), findsNothing);
      expect(find.text('打开'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an empty image set and out-of-range initial index are safe', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: FanartImageViewer(images: [], initial: 10)),
    );
    expect(find.text('没有图片'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final uri = Uri.parse('https://fixture.test/replacement');
    await cacheImageFixture(
      tester,
      uri,
      provider: MediaImagePolicy.original(
        uri,
        viewportWidth:
            tester.view.physicalSize.width / tester.view.devicePixelRatio,
        devicePixelRatio: tester.view.devicePixelRatio,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: FanartImageViewer(images: [uri], initial: 10)),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
