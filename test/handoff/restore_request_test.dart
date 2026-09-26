import 'dart:async';

import 'package:asasfans_next/app/providers.dart';
import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/core/platform/external_link_service.dart';
import 'package:asasfans_next/features/content/application/content_providers.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/features/content/presentation/content_page.dart';
import 'package:asasfans_next/features/handoff/application/handoff_coordinator.dart';
import 'package:asasfans_next/features/handoff/application/handoff_providers.dart';
import 'package:asasfans_next/features/handoff/data/sqlite_return_store.dart';
import 'package:asasfans_next/features/handoff/domain/return_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/library_fixture.dart';
import '../helpers/sqlite_fixture.dart';

FanartItem _item(String id) => FanartItem(
  identity: ContentIdentity(source: ContentSource.bilibiliDynamic, value: id),
  text: '作品 $id',
  authorName: '作者',
  authorUid: '1',
  images: const [],
  kind: FanartKind.fanart,
  contentType: FanartContentType.text,
  sourceUrl: Uri.https('t.bilibili.com', '/$id'),
  category: FanartCategory.normal,
  characterTags: const [],
);

/// Twelve works a page, three pages; the second page waits for [gate].
class _Gated implements FanartRepository {
  final gate = Completer<void>();
  @override
  Future<FanartPage> page({
    FanartQuery query = const FanartQuery(),
    String? cursor,
    RequestCancellation? cancellation,
  }) async {
    final page = cursor == null ? 0 : int.parse(cursor);
    if (page == 1) await gate.future;
    return FanartPage(
      items: [for (var i = 0; i < 12; i++) _item('${page * 12 + i}')],
      snapshotId: 's',
      nextCursor: page < 2 ? '${page + 1}' : null,
    );
  }

  @override
  Future<FanartItem?> random({
    FanartQuery query = const FanartQuery(),
    RequestCancellation? cancellation,
  }) async => null;
}

class _Links implements ExternalLinkService {
  @override
  Future<bool> open(Uri uri) async => true;
}

/// R04: a restore is one request. It is claimed by the feed it names,
/// cancelled only by its own id, and gives way to what the user does
/// meanwhile.
void main() {
  late MemoryLocalDatabase db;
  late SqliteReturnStore store;
  setUp(() {
    db = MemoryLocalDatabase();
    store = SqliteReturnStore(db);
  });
  tearDown(() => db.close());

  Future<HandoffCoordinator> leftFrom(String channel) async {
    final coordinator = HandoffCoordinator(_Links(), store);
    await coordinator.open(
      url: Uri.https('t.bilibili.com', '/9'),
      target: ReturnTarget.contentChannel,
      channel: channel,
      query: const {
        'characters': ['diana'],
      },
      anchor: ReturnAnchor(identity: _item('30').identity),
    );
    return coordinator;
  }

  test('an old request cannot cancel a newer one', () async {
    final coordinator = await leftFrom('fanart');
    final first = coordinator.resumeBrowsing()!;
    final second = coordinator.resumeBrowsing()!;
    expect(second, isNot(first));
    coordinator.cancelBrowseRestore(first);
    expect(coordinator.hasBrowseRestoreFor('fanart'), isTrue);
    coordinator.cancelBrowseRestore(second);
    expect(coordinator.hasBrowseRestoreFor('fanart'), isFalse);
  });

  test(
    'a claimed request is gone; cancelling it later changes nothing',
    () async {
      final coordinator = await leftFrom('fanart');
      final request = coordinator.resumeBrowsing()!;
      expect(await coordinator.listRestoreFor('fanart'), isNotNull);
      final next = coordinator.resumeBrowsing()!;
      coordinator.cancelBrowseRestore(request);
      // The newer request survives the stale cancel.
      expect(coordinator.hasBrowseRestoreFor('fanart'), isTrue);
      expect(
        (await coordinator.listRestoreFor('fanart'))?.sessionId,
        'browse-$next',
      );
    },
  );

  test('nothing to resume gives no request', () {
    final coordinator = HandoffCoordinator(_Links(), store);
    expect(coordinator.resumeBrowsing(), isNull);
  });

  testWidgets('a feed built late still claims its request', (tester) async {
    final coordinator = await tester.runAsync(() => leftFrom('fanart'));
    coordinator!.resumeBrowsing();
    // Several frames pass before the feed exists (a slow route).
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final repository = _Gated()..gate.complete();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...offlineLibrary(),
          returnStoreProvider.overrideWithValue(store),
          handoffCoordinatorProvider.overrideWithValue(coordinator),
          fanartRepositoryProvider.overrideWithValue(repository),
          externalLinkServiceProvider.overrideWithValue(_Links()),
        ],
        child: const MaterialApp(home: ContentPage(channel: 'fanart')),
      ),
    );
    await tester.pumpAndSettle();
    expect(coordinator.hasBrowseRestoreFor('fanart'), isFalse);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ContentPage)),
    );
    expect(
      container
          .read(fanartFeedControllerProvider(ContentChannel.fanart))
          .state
          .query
          .characters,
      {FanartCharacter.diana},
    );
  });

  testWidgets('a query the user commits during a restore wins', (tester) async {
    tester.view
      ..physicalSize = const Size(1000, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final coordinator = await tester.runAsync(() => leftFrom('fanart'));
    final repository = _Gated();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...offlineLibrary(),
          returnStoreProvider.overrideWithValue(store),
          handoffCoordinatorProvider.overrideWithValue(coordinator!),
          fanartRepositoryProvider.overrideWithValue(repository),
          externalLinkServiceProvider.overrideWithValue(_Links()),
        ],
        child: const MaterialApp(home: ContentPage(channel: 'fanart')),
      ),
    );
    await tester.pump();
    coordinator.resumeBrowsing();
    // The restore is now waiting on the second page for work 30.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // Meanwhile the user picks another member.
    await tester.tap(find.text('贝拉').first);
    await tester.pump();
    repository.gate.complete();
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ContentPage)),
    );
    final feed = container.read(
      fanartFeedControllerProvider(ContentChannel.fanart),
    );
    // The member strip adds to the restored choice; the restore does not
    // put its own query back over it.
    expect(feed.state.query.characters, {
      FanartCharacter.diana,
      FanartCharacter.bella,
    });
    // The stale restore neither moved the list nor reported a lost place.
    final list = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .firstWhere((state) => state.axisDirection == AxisDirection.down);
    expect(list.position.pixels, 0);
    expect(find.text('原位置已不在列表中，已回到相近位置'), findsNothing);
  });
}
