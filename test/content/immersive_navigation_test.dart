import '../helpers/library_fixture.dart';
import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/features/content/application/content_providers.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/features/content/presentation/content_page.dart';
import 'package:asasfans_next/features/content/presentation/fanart_detail_page.dart';
import 'package:asasfans_next/features/content/presentation/fanart_image_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Repository implements FanartRepository {
  int calls = 0;
  @override
  Future<FanartPage> page({
    FanartQuery query = const FanartQuery(),
    String? cursor,
    RequestCancellation? cancellation,
  }) async {
    calls++;
    return FanartPage(
      items: [
        for (var i = 0; i < 10; i++)
          FanartItem(
            identity: ContentIdentity(
              source: ContentSource.bilibiliDynamic,
              value: '$i',
            ),
            text: '作品 $i',
            authorName: '作者',
            authorUid: '1',
            images: [Uri.parse('https://image.test/fixture.png')],
            kind: FanartKind.fanart,
            contentType: FanartContentType.image,
            category: FanartCategory.normal,
            characterTags: const [],
          ),
      ],
      snapshotId: 's',
    );
  }

  @override
  Future<FanartItem?> random({
    FanartQuery query = const FanartQuery(),
    RequestCancellation? cancellation,
  }) async => null;
}

void main() {
  testWidgets(
    'detail and artwork cover a nested shell, then return to the same loaded feed',
    (tester) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = _Repository();
      final router = GoRouter(
        initialLocation: '/content',
        routes: [
          ShellRoute(
            builder: (_, _, child) => Scaffold(
              body: child,
              bottomNavigationBar: NavigationBar(
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.home), label: '今日'),
                  NavigationDestination(
                    icon: Icon(Icons.grid_view),
                    label: '内容',
                  ),
                ],
              ),
            ),
            routes: [
              GoRoute(
                path: '/content',
                builder: (_, _) => const ContentPage(channel: 'fanart'),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...offlineLibrary(),
            fanartRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.tap(find.text('作品 0'));
      await tester.pumpAndSettle();
      expect(find.byType(FanartDetailPage), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tap(find.byType(Image).first);
      await tester.pumpAndSettle();
      expect(find.byType(FanartImageViewer), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      // The pages use the app's own bar, so go back the way Android does.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(FanartDetailPage), findsOneWidget);
      // The pages use the app's own bar, so go back the way Android does.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('作品 0'), findsOneWidget);
      expect(repository.calls, 1);
    },
  );
}
