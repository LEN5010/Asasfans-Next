import 'dart:async';

import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/core/platform/external_link_service.dart';
import 'package:asasfans_next/features/content/application/content_providers.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/features/content/presentation/content_page.dart';
import 'package:asasfans_next/features/content/presentation/fanart_card.dart';
import 'package:asasfans_next/features/handoff/application/handoff_coordinator.dart';
import 'package:asasfans_next/features/handoff/application/handoff_providers.dart';
import 'package:asasfans_next/features/handoff/data/sqlite_return_store.dart';
import 'package:asasfans_next/features/handoff/domain/return_context.dart';
import 'package:asasfans_next/features/handoff/presentation/continue_browsing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_fixture.dart';
import '../visual/visual_harness.dart';

class _Links implements ExternalLinkService {
  _Links({this.accept = true});
  final bool accept;
  @override
  Future<bool> open(Uri uri) async => accept;
}

const _anchor = ReturnAnchor(
  identity: ContentIdentity(source: ContentSource.bilibiliDynamic, value: '9'),
);

void main() {
  late MemoryLocalDatabase db;
  late SqliteReturnStore store;
  setUp(() {
    db = MemoryLocalDatabase();
    store = SqliteReturnStore(db);
  });
  tearDown(() => db.close());

  Future<HandoffResult> tripFrom(
    HandoffCoordinator coordinator, {
    ReturnTarget target = ReturnTarget.contentChannel,
    String? channel = 'fanart',
  }) => coordinator.open(
    url: Uri.https('t.bilibili.com', '/9'),
    target: target,
    channel: channel,
    query: const {'characters': 'diana', 'category': 'handwriting'},
    anchor: _anchor,
  );

  test('a trip out from a channel leaves a snapshot; others do not', () async {
    final coordinator = HandoffCoordinator(_Links(), store);
    await tripFrom(coordinator, target: ReturnTarget.today, channel: null);
    expect(coordinator.browsing, isNull);
    await tripFrom(coordinator);
    expect(coordinator.browsing?.channel, 'fanart');
    expect(coordinator.browsing?.anchor?.identity, _anchor.identity);

    // A trip the system refused is not somewhere the user was.
    final refused = HandoffCoordinator(_Links(accept: false), store);
    await tripFrom(refused);
    expect(refused.browsing, isNull);
  });

  test('resuming feeds the named channel once and never the store', () async {
    final coordinator = HandoffCoordinator(_Links(), store);
    await tripFrom(coordinator);
    final session = (await store.read())!;
    await store.consume(session.sessionId);
    // The consumed return session is not replayed by itself.
    expect(await coordinator.listRestoreFor('fanart'), isNull);

    coordinator.resumeBrowsing();
    expect(coordinator.hasBrowseRestoreFor('fanart'), isTrue);
    expect(coordinator.hasBrowseRestoreFor('dynamics'), isFalse);
    expect(await coordinator.listRestoreFor('dynamics'), isNull);
    final restore = await coordinator.listRestoreFor('fanart');
    expect(restore?.query?['characters'], 'diana');
    expect(restore?.anchor?.identity, _anchor.identity);
    // Used up, and the stored session is untouched.
    expect(await coordinator.listRestoreFor('fanart'), isNull);
    expect((await store.read())!.consumed, isTrue);
    expect((await store.read())!.sessionId, session.sessionId);
  });

  test('forgetting drops the snapshot and any waiting restore', () async {
    final coordinator = HandoffCoordinator(_Links(), store);
    await tripFrom(coordinator);
    coordinator.resumeBrowsing();
    coordinator.forgetBrowsing();
    expect(coordinator.browsing, isNull);
    expect(coordinator.hasBrowseRestoreFor('fanart'), isFalse);
  });

  test('the row names the channel and the conditions actually applied', () {
    BrowseSnapshot at(String channel, Map<String, Object?> query) =>
        BrowseSnapshot(channel: channel, query: query, at: DateTime.utc(2026));
    expect(
      describeBrowse(
        at('fanart', const {
          'characters': ['diana'],
          'category': 'handwriting',
        }),
      ),
      ['二创', '嘉然', '手书·动画'],
    );
    expect(
      describeBrowse(at('clips', const {'order': 'score', 'withinDays': 7})),
      ['切片', '最热', '一周内'],
    );
    expect(describeBrowse(at('latest', const {'order': 'newest'})), ['视频']);
    expect(browseRoute('clips'), '/content/videos?kind=clips');
    expect(browseRoute('fanart'), '/content/fanart');
    expect(browseRoute('unknown'), isNull);
  });

  setUpAll(Visual.setUp);

  testVisual('Today leads back to the channel, query and item', (tester) async {
    await pumpVisualApp(
      tester,
      view: VisualView.phone,
      location: '/content/fanart',
    );
    // Narrow the channel, then leave for B站 from a video work.
    await tester.tap(find.text('嘉然').first);
    await settleVisual(tester);
    final video = find.byWidgetPredicate(
      (widget) =>
          widget is FanartCard &&
          widget.item.contentType == FanartContentType.video,
    );
    // Built lazily: scroll the feed until the tile exists, then centre it.
    final list = find
        .descendant(
          of: find.byType(ContentPage),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        )
        .first;
    await tester.scrollUntilVisible(video, 200, scrollable: list);
    await tester.runAsync(
      () => Scrollable.ensureVisible(tester.element(video), alignment: .4),
    );
    await settleVisual(tester);
    final left = tester.widget<FanartCard>(video).item.identity;
    await tester.tap(video);
    await settleVisual(tester);

    final container = visualContainer(tester);
    expect(container.read(handoffCoordinatorProvider).browsing, isNotNull);

    // Meanwhile the channel moves on to all members.
    unawaited(
      container
          .read(fanartFeedControllerProvider(ContentChannel.fanart))
          .applyQuery(const FanartQuery()),
    );
    await settleVisual(tester);

    visualRouter(tester).go('/today');
    await settleVisual(tester);
    expect(find.bySemanticsLabel(RegExp('继续挑选：二创 · 嘉然')), findsOneWidget);
    await shoot(tester, 'flow-continue-1-today', VisualView.phone);

    await tester.tap(find.byType(ContinueBrowsingRow));
    await settleVisual(tester);
    final feed = container.read(
      fanartFeedControllerProvider(ContentChannel.fanart),
    );
    expect(feed.state.query.characters, {FanartCharacter.diana});
    // The item left from is back on screen, clear of the page bar.
    final tile = find.byWidgetPredicate(
      (widget) => widget is FanartCard && widget.item.identity == left,
    );
    expect(tile, findsOneWidget);
    expect(tester.getRect(tile).top, greaterThan(100));
    expect(tester.getRect(tile).bottom, lessThan(844));
    await shoot(tester, 'flow-continue-2-restored', VisualView.phone);

    // Dismissing forgets only the snapshot.
    visualRouter(tester).go('/today');
    await settleVisual(tester);
    await tester.tap(find.byTooltip('不再显示继续挑选'));
    await settleVisual(tester);
    expect(find.byType(ContinueBrowsingRow), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('继续挑选')), findsNothing);
  });
}
