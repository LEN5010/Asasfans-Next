import '../helpers/library_fixture.dart';
import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/content/application/content_providers.dart';
import 'package:asasfans_next/features/content/domain/dynamic_repository.dart';
import 'package:asasfans_next/features/content/presentation/content_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

DynamicPost _post(String id, {String? text, ForwardedPost? forwarded}) =>
    DynamicPost(
      identity: ContentIdentity(
        source: ContentSource.bilibiliDynamic,
        value: id,
      ),
      member: const DynamicMember(id: 'uid:1', name: '嘉然今天吃什么'),
      type: forwarded == null ? DynamicType.text : DynamicType.forward,
      text: text ?? '动态 $id',
      images: const [],
      publishedAt: DateTime.utc(2021, 8, 15, 20),
      forwardedFrom: forwarded,
    );

class _StubRepository implements DynamicRepository {
  _StubRepository({this.pages = 2, this.failFirst = false});

  final int pages;
  final bool failFirst;
  final List<DynamicQuery> queries = [];
  int requests = 0;

  @override
  Future<DynamicPage> search({
    DynamicQuery query = const DynamicQuery(),
    String? cursor,
    RequestCancellation? cancellation,
  }) async {
    requests++;
    queries.add(query);
    if (failFirst && requests == 1) {
      throw const ApiFailure(ApiFailureKind.offline);
    }
    final index = cursor == null ? 0 : int.parse(cursor);
    return DynamicPage(
      items: [for (var i = 0; i < 6; i++) _post('p${index}i$i')],
      nextCursor: index + 1 < pages ? '${index + 1}' : null,
    );
  }

  @override
  Future<List<DynamicPost>> onThisDay({
    String? monthDay,
    OnThisDaySort sort = OnThisDaySort.hot,
    int limit = 8,
  }) async => const [];

  @override
  Future<List<DynamicMember>> members() async => const [];
}

Widget _app(DynamicRepository repository) => ProviderScope(
  overrides: [
    ...offlineLibrary(),
    dynamicRepositoryProvider.overrideWithValue(repository),
  ],
  child: const MaterialApp(home: ContentPage(channel: 'dynamics')),
);

void main() {
  testWidgets('the dynamics channel renders posts instead of a placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_StubRepository()));
    await tester.pumpAndSettle();

    expect(find.text('即将开放'), findsNothing);
    expect(find.text('动态 p0i0'), findsOneWidget);
    // Timestamps are labelled on the Shanghai calendar the archive uses.
    expect(find.text('2021-08-16'), findsWidgets);
  });

  testWidgets('a forward shows its origin rather than claiming it', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_ForwardRepository()));
    await tester.pumpAndSettle();

    expect(find.text('转发语'), findsOneWidget);
    expect(find.text('@原作者'), findsOneWidget);
    expect(find.text('被转发的原文'), findsOneWidget);
  });

  testWidgets('filtering by type starts a new query without a cursor', (
    tester,
  ) async {
    final repository = _StubRepository();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    expect(repository.queries.last.type, isNull);

    await tester.tap(find.widgetWithText(ChoiceChip, '视频'));
    await tester.pumpAndSettle();

    expect(repository.queries.last.type, DynamicType.video);
  });

  testWidgets('searching applies the keyword on submit', (tester) async {
    final repository = _StubRepository();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '生日');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(repository.queries.last.keyword, '生日');
  });

  testWidgets('a first page failure offers a retry', (tester) async {
    final repository = _StubRepository(failFirst: true, pages: 1);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.text('网络连接失败'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '重试'));
    await tester.pumpAndSettle();

    expect(find.text('动态 p0i0'), findsOneWidget);
  });
}

class _ForwardRepository extends _StubRepository {
  @override
  Future<DynamicPage> search({
    DynamicQuery query = const DynamicQuery(),
    String? cursor,
    RequestCancellation? cancellation,
  }) async => DynamicPage(
    items: [
      _post(
        '1',
        text: '转发语',
        forwarded: const ForwardedPost(
          authorName: '原作者',
          text: '被转发的原文',
          images: [],
        ),
      ),
    ],
  );
}
