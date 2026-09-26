import 'package:asasfans_next/app/providers.dart';
import 'package:asasfans_next/core/platform/external_link_service.dart';
import 'package:asasfans_next/app/router/app_router.dart';
import 'package:asasfans_next/core/storage/storage_providers.dart';
import 'package:asasfans_next/features/content/application/content_providers.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/features/content/presentation/content_page.dart';
import 'package:asasfans_next/features/content/presentation/fanart_card.dart';
import 'package:asasfans_next/features/content/presentation/fanart_detail_page.dart';
import 'package:asasfans_next/features/handoff/application/handoff_providers.dart';
import 'package:asasfans_next/features/handoff/domain/return_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_fixture.dart';
import '../visual/visual_harness.dart';

class _Links implements ExternalLinkService {
  final opened = <Uri>[];
  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}

/// R01: a work opened into its detail page from a narrowed channel still
/// returns to that channel when the user goes on to the original post.
void main() {
  setUpAll(Visual.setUp);
  const view = VisualView.phone;

  Finder tileOf(String id) => find.byWidgetPredicate(
    (widget) => widget is FanartCard && widget.item.identity.value == id,
  );

  Finder feedList() => find
      .descendant(
        of: find.byType(ContentPage),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      )
      .first;

  /// Narrows 二创 to 嘉然, opens work [id] into its detail page and goes on to
  /// the original post from there.
  Future<void> detailTrip(WidgetTester tester, String id) async {
    await tester.tap(find.text('嘉然').first);
    await settleVisual(tester);
    await tester.scrollUntilVisible(tileOf(id), 200, scrollable: feedList());
    await tester.runAsync(
      () => Scrollable.ensureVisible(tester.element(tileOf(id)), alignment: .4),
    );
    await settleVisual(tester);
    await tester.tap(tileOf(id));
    await settleVisual(tester);
    expect(find.byType(FanartDetailPage), findsOneWidget);
    await tester.tap(find.byTooltip('打开原动态'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await settleVisual(tester);
  }

  for (final (label, id) in [('multi-image', '900001'), ('text', '900003')]) {
    testVisual('a $label work returns to the narrowed channel', (tester) async {
      final links = _Links();
      final container = await pumpVisualApp(
        tester,
        view: view,
        location: '/content/fanart',
        overrides: visualOverrides(
          extra: [externalLinkServiceProvider.overrideWithValue(links)],
        ),
      );
      await detailTrip(tester, id);
      expect(links.opened, [Uri.https('t.bilibili.com', '/$id')]);

      final stored = await tester.runAsync(
        () => container.read(returnStoreProvider).read(),
      );
      expect(stored!.target, ReturnTarget.contentChannel);
      expect(stored.channel, 'fanart');
      expect(stored.query?['characters'], ['diana']);
      expect(stored.anchor?.identity?.value, id);
      final browsing = container.read(handoffCoordinatorProvider).browsing;
      expect(browsing?.channel, 'fanart');
      expect(browsing?.anchor?.identity?.value, id);
    });
  }

  testVisual('a work opened from Today keeps Today as its return', (
    tester,
  ) async {
    final container = await pumpVisualApp(tester, view: view);
    final tile = find.byType(FanartCard).first;
    await tester.runAsync(
      () => Scrollable.ensureVisible(tester.element(tile), alignment: .4),
    );
    await settleVisual(tester);
    final item = tester.widget<FanartCard>(tile).item;
    // A video work leaves directly; the detail page is for the others.
    expect(item.contentType, isNot(FanartContentType.video));
    await tester.tap(tile);
    await settleVisual(tester);
    await tester.tap(find.byTooltip('打开原动态'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await settleVisual(tester);
    final stored = await tester.runAsync(
      () => container.read(returnStoreProvider).read(),
    );
    expect(stored!.target, ReturnTarget.today);
    expect(stored.channel, isNull);
    expect(container.read(handoffCoordinatorProvider).browsing, isNull);
  });

  testVisual('a cold start after the detail trip rebuilds the channel', (
    tester,
  ) async {
    // One database outlives both app processes, as the file would.
    final database = MemoryLocalDatabase();
    addTearDown(database.close);
    List<Override> process(_Links links) => visualOverrides(
      extra: [
        externalLinkServiceProvider.overrideWithValue(links),
        localDatabaseProvider.overrideWithValue(database),
      ],
    );

    final first = _Links();
    await pumpVisualApp(
      tester,
      view: view,
      location: '/content/fanart',
      overrides: process(first),
    );
    await detailTrip(tester, '900001');
    expect(first.opened, hasLength(1));
    // Bilibili is in front and the process is reclaimed.
    await tester.pumpWidget(const SizedBox());

    final second = _Links();
    final container = await pumpVisualApp(
      tester,
      view: view,
      overrides: process(second),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await settleVisual(tester);
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/content/fanart',
    );
    expect(
      container
          .read(fanartFeedControllerProvider(ContentChannel.fanart))
          .state
          .query
          .characters,
      {FanartCharacter.diana},
    );
    // Restoring never opens the post again.
    expect(second.opened, isEmpty);
  });
}
