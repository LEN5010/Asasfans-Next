import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/app/providers.dart';
import 'package:asasfans_next/core/platform/external_link_service.dart';
import 'package:asasfans_next/features/content/application/content_providers.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
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

FanartItem _item(String id) => FanartItem(
  identity: ContentIdentity(source: ContentSource.bilibiliDynamic, value: id),
  text: '作品 $id',
  authorName: '作者',
  authorUid: '1',
  images: const [],
  kind: FanartKind.fanart,
  contentType: FanartContentType.video,
  sourceUrl: Uri.https('t.bilibili.com', '/$id'),
  category: FanartCategory.normal,
  characterTags: const [],
);

/// Records the queries it is asked for, so a restore can be observed rather
/// than inferred from what ends up on screen.
class _Recording implements FanartRepository {
  _Recording({this.pageSize = 6, this.pages = 1});
  final int pageSize;
  final int pages;
  final queries = <FanartQuery>[];
  final cursors = <String?>[];
  @override
  Future<FanartPage> page({
    FanartQuery query = const FanartQuery(),
    String? cursor,
    RequestCancellation? cancellation,
  }) async {
    queries.add(query);
    cursors.add(cursor);
    final page = cursor == null ? 0 : int.parse(cursor);
    return FanartPage(
      items: [
        for (var i = 0; i < pageSize; i++) _item('${page * pageSize + i}'),
      ],
      snapshotId: 's',
      nextCursor: page + 1 < pages ? '${page + 1}' : null,
    );
  }

  @override
  Future<FanartItem?> random({
    FanartQuery query = const FanartQuery(),
    RequestCancellation? cancellation,
  }) async => _item('r');
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
  late _Recording repository;
  late _Links links;
  setUp(() {
    db = MemoryLocalDatabase();
    store = SqliteReturnStore(db);
    repository = _Recording();
    links = _Links();
  });
  tearDown(() => db.close());

  Future<void> pumpChannel(
    WidgetTester tester, {
    void Function(ProviderContainer)? beforeSettle,
  }) async {
    tester.view
      ..physicalSize = const Size(1000, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        ...offlineLibrary(),
        returnStoreProvider.overrideWithValue(store),
        fanartRepositoryProvider.overrideWithValue(repository),
        externalLinkServiceProvider.overrideWithValue(links),
      ],
    );
    addTearDown(container.dispose);
    // Before the first frame, as the restorer grants before navigating.
    beforeSettle?.call(container);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ContentPage(channel: 'fanart')),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> seedSession({
    required String channel,
    Map<String, Object?>? query,
    ReturnAnchor? anchor,
    bool consumed = false,
  }) => store.save(
    ReturnContext(
      sessionId: 'session-1',
      target: ReturnTarget.contentChannel,
      channel: channel,
      createdAt: DateTime.utc(2026, 9, 22),
      query: query,
      anchor: anchor,
      consumed: consumed,
    ),
  );

  /// Visible means the card's painted rect overlaps the part of the viewport
  /// not covered by the floating page bar — not merely that it was built.
  bool onScreen(WidgetTester tester, String text) {
    final finder = find.text(text);
    if (finder.evaluate().isEmpty) return false;
    final rect = tester.getRect(finder.first);
    final view = Offset.zero & tester.view.physicalSize;
    return rect.overlaps(view.deflate(1)) && rect.top > 60;
  }

  testWidgets('a cold return re-applies the committed query', (tester) async {
    await seedSession(
      channel: 'fanart',
      query: ChannelSpec.ofFanart(
        const FanartQuery(
          keyword: '生日',
          characters: {FanartCharacter.diana},
          contentType: FanartContentType.video,
        ),
      ).values,
    );
    await pumpChannel(tester);
    final restored = repository.queries.last;
    expect(restored.keyword, '生日');
    expect(restored.characters, {FanartCharacter.diana});
    expect(restored.contentType, FanartContentType.video);
  });

  testWidgets('no session leaves the channel on its default query', (
    tester,
  ) async {
    await pumpChannel(tester);
    expect(repository.queries, isNotEmpty);
    expect(repository.queries.single, const FanartQuery());
  });

  testWidgets('a video handoff preserves the committed query and anchor', (
    tester,
  ) async {
    final query = ChannelSpec.ofFanart(
      const FanartQuery(keyword: '生日', contentType: FanartContentType.video),
    ).values;
    await seedSession(channel: 'fanart', query: query);
    await pumpChannel(tester);
    await tester.tap(find.text('作品 2'));
    await tester.pumpAndSettle();
    final saved = (await store.read())!;
    expect(links.opened, [Uri.https('t.bilibili.com', '/2')]);
    expect(saved.channel, 'fanart');
    expect(saved.query, query);
    expect(saved.anchor!.identity, _item('2').identity);
    expect(saved.anchor!.offset, 0);
  });

  testWidgets('a session for another channel does not change this one', (
    tester,
  ) async {
    await seedSession(
      channel: 'clips',
      query: ChannelSpec.ofFanart(const FanartQuery(keyword: '不该应用到二创')).values,
    );
    await pumpChannel(tester);
    expect(repository.queries.single, const FanartQuery());
  });

  testWidgets('a session with no stored query still loads normally', (
    tester,
  ) async {
    await seedSession(channel: 'fanart');
    await pumpChannel(tester);
    expect(repository.queries.single, const FanartQuery());
  });

  testWidgets('browsing is not blocked while the session is read', (
    tester,
  ) async {
    // The first fetch must not wait on storage: the common case has no session,
    // and a slow store would otherwise delay ordinary browsing.
    await seedSession(channel: 'fanart');
    await pumpChannel(tester);
    expect(find.text('作品 0'), findsWidgets);
  });

  testWidgets('an anchored item already on screen needs no jump', (
    tester,
  ) async {
    await seedSession(
      channel: 'fanart',
      anchor: ReturnAnchor(identity: _item('2').identity, offset: 9999),
    );
    await pumpChannel(tester);
    // The stored offset is deliberately absurd; since the item is loaded, the
    // identity wins and no clamped jump to the end happens.
    expect(tester.takeException(), isNull);
    expect(find.text('作品 0'), findsWidgets);
  });

  testWidgets('a restore does not re-open anything externally', (tester) async {
    await seedSession(
      channel: 'fanart',
      query: ChannelSpec.ofFanart(const FanartQuery(keyword: '生日')).values,
    );
    await pumpChannel(tester);
    // openedContent is remembered for context only; coming back must not bounce
    // the user out again, so nothing was handed to the link service.
    expect(tester.takeException(), isNull);
    expect(find.byType(ContentPage), findsOneWidget);
  });

  testWidgets(
    'a cold return scrolls a loaded but off-screen anchor into view',
    (tester) async {
      repository = _Recording(pageSize: 48);
      await seedSession(
        channel: 'fanart',
        // The offset is from another layout: the identity must win over it.
        anchor: ReturnAnchor(identity: _item('40').identity, offset: 0),
      );
      await pumpChannel(tester);
      expect(onScreen(tester, '作品 40'), isTrue);
      expect(onScreen(tester, '作品 0'), isFalse);
    },
  );

  testWidgets('an anchor on a later page loads a bounded number of pages', (
    tester,
  ) async {
    repository = _Recording(pageSize: 12, pages: 3);
    await seedSession(
      channel: 'fanart',
      anchor: ReturnAnchor(identity: _item('30').identity),
    );
    await pumpChannel(tester);
    expect(onScreen(tester, '作品 30'), isTrue);
  });

  testWidgets('a missing anchor falls back to the offset and says so', (
    tester,
  ) async {
    repository = _Recording(pageSize: 48);
    await seedSession(
      channel: 'fanart',
      anchor: ReturnAnchor(identity: _item('gone').identity, offset: 800),
    );
    await pumpChannel(tester);
    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const PageStorageKey('fanart-feed')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(scrollable.position.pixels, 800);
    expect(find.textContaining('原位置'), findsOneWidget);
  });

  testWidgets('a session an earlier launch already used is not replayed', (
    tester,
  ) async {
    await seedSession(
      channel: 'fanart',
      consumed: true,
      query: ChannelSpec.ofFanart(const FanartQuery(keyword: '旧的')).values,
    );
    await pumpChannel(tester);
    expect(repository.queries.single, const FanartQuery());
  });

  testWidgets('a warm return is not replayed when the feed is rebuilt', (
    tester,
  ) async {
    await seedSession(
      channel: 'fanart',
      query: ChannelSpec.ofFanart(const FanartQuery(keyword: '旧的')).values,
    );
    // The warm path consumes quietly: the list was alive, nothing to rebuild.
    await store.consume('session-1');
    await pumpChannel(tester);
    expect(repository.queries.single, const FanartQuery());
  });

  testWidgets('a cold start rebuilds the list it navigated to', (tester) async {
    await seedSession(
      channel: 'fanart',
      query: ChannelSpec.ofFanart(const FanartQuery(keyword: '生日')).values,
    );
    await store.consume('session-1');
    await pumpChannel(
      tester,
      beforeSettle: (container) => container
          .read(handoffCoordinatorProvider)
          .grantListRestore('session-1'),
    );
    expect(repository.queries.last.keyword, '生日');
  });

  testWidgets('an anchor already on the first page fetches nothing more', (
    tester,
  ) async {
    repository = _Recording(pageSize: 48, pages: 3);
    await seedSession(
      channel: 'fanart',
      anchor: ReturnAnchor(identity: _item('10').identity),
    );
    await pumpChannel(tester);
    expect(onScreen(tester, '作品 10'), isTrue);
    expect(repository.cursors, [null]);
  });
}
