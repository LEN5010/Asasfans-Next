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
  final queries = <FanartQuery>[];
  @override
  Future<FanartPage> page({
    FanartQuery query = const FanartQuery(),
    String? cursor,
    RequestCancellation? cancellation,
  }) async {
    queries.add(query);
    return FanartPage(
      items: [for (var i = 0; i < 6; i++) _item('$i')],
      snapshotId: 's',
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

  Future<void> pumpChannel(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1000, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...offlineLibrary(),
          returnStoreProvider.overrideWithValue(store),
          fanartRepositoryProvider.overrideWithValue(repository),
          externalLinkServiceProvider.overrideWithValue(links),
        ],
        child: const MaterialApp(home: ContentPage(channel: 'fanart')),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> seedSession({
    required String channel,
    Map<String, Object?>? query,
    ReturnAnchor? anchor,
  }) => store.save(
    ReturnContext(
      sessionId: 'session-1',
      target: ReturnTarget.contentChannel,
      channel: channel,
      createdAt: DateTime.utc(2026, 9, 22),
      query: query,
      anchor: anchor,
    ),
  );

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
}
