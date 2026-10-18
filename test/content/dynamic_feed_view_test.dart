import '../helpers/library_fixture.dart';
import 'package:asasfans_next/shared/widgets/app_controls.dart';
import 'package:asasfans_next/features/content/presentation/dynamic_card.dart';
import 'package:asasfans_next/features/content/presentation/dynamic_rich_text.dart';
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
      publishedAt: DateTime(2021, 8, 16, 4).toUtc(),
      forwardedFrom: forwarded,
    );

class _StubRepository implements DynamicRepository {
  _StubRepository({
    this.pages = 2,
    this.failFirst = false,
    this.members_ = const [],
  });

  final int pages;
  final bool failFirst;
  final List<DynamicMember> members_;
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
  Future<List<DynamicMember>> members() async => members_;
}

Widget _app(
  DynamicRepository repository, {
  TextScaler textScaler = TextScaler.noScaling,
}) => ProviderScope(
  overrides: [
    ...offlineLibrary(),
    dynamicRepositoryProvider.overrideWithValue(repository),
  ],
  child: MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: child!,
    ),
    home: const ContentPage(channel: 'dynamics'),
  ),
);

void main() {
  testWidgets(
    'UI UX: full dynamic body preserves line breaks and exact stickers',
    (tester) async {
      const body = '首行\n[心宜和思诺的交响乐谱_吃饭]\n[未知表情]\n四行\n五行\n六行\n七行\n最后一行';
      await tester.pumpWidget(
        ProviderScope(
          overrides: offlineLibrary(),
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DynamicCard(post: _post('10', text: body)),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rich = tester.widget<DynamicRichText>(find.byType(DynamicRichText));
      expect(rich.text, body);
      expect(rich.maxLines, isNull);
      final rendered = tester.widget<Text>(
        find.descendant(
          of: find.byType(DynamicRichText),
          matching: find.byType(Text),
        ),
      );
      expect(
        (rendered.textSpan as TextSpan).children!.whereType<WidgetSpan>(),
        hasLength(1),
      );
      expect(rendered.textSpan!.toPlainText(), contains('[未知表情]'));
      expect(rendered.textSpan!.toPlainText(), contains('最后一行'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the dynamics channel renders posts instead of a placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_StubRepository()));
    await tester.pumpAndSettle();

    expect(find.text('即将开放'), findsNothing);
    expect(find.text('动态 p0i0'), findsOneWidget);
    // Timestamps are labelled in the device timezone.
    expect(find.textContaining('2021-08-16 04:00'), findsWidgets);
  });

  testWidgets('a forward shows its origin rather than claiming it', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_ForwardRepository()));
    await tester.pumpAndSettle();

    expect(find.text('转发语'), findsOneWidget);
    expect(find.text('转发自 @原作者'), findsOneWidget);
    expect(find.text('被转发的原文'), findsOneWidget);
  });

  testWidgets(
    'UI UX: dynamic filters apply drafts and discard cancelled changes',
    (tester) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = _StubRepository();
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      expect(repository.queries.last.type, isNull);

      await tester.tap(find.byTooltip('筛选与排序'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, '视频'));
      await tester.pumpAndSettle();
      expect(repository.queries.last.type, isNull);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(repository.queries.last.type, isNull);
      await tester.tap(find.byTooltip('筛选与排序'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, '视频'));
      await tester.tap(find.text('应用筛选'));
      await tester.pumpAndSettle();
      expect(repository.queries.last.type, DynamicType.video);
    },
  );

  testWidgets(
    'more members require acknowledgement and retain the selected filter',
    (tester) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = _StubRepository(
        members_: const [DynamicMember(id: 'uid:672346917', name: '向晚')],
      );
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('筛选与排序'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('向晚'), findsNothing);
      await tester.tap(find.widgetWithText(AppButton, '更多成员'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byTooltip('向晚'), findsNothing);
      await tester.tap(find.text('我已了解，继续'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(find.byTooltip('向晚'));
      expect(repository.queries.last.memberId, isNull);
      await tester.ensureVisible(find.text('应用筛选'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('应用筛选'));
      await tester.pumpAndSettle();
      expect(repository.queries.last.memberId, 'uid:672346917');
      await tester.tap(find.byTooltip('筛选与排序'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('向晚'), findsOneWidget);
      expect(
        tester
            .widget<AppButton>(
              find.byWidgetPredicate(
                (widget) => widget is AppButton && widget.tooltip == '向晚',
              ),
            )
            .selected,
        isTrue,
      );
    },
  );

  testWidgets('searching applies the keyword on submit', (tester) async {
    final repository = _StubRepository();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    // Search is an inline field at the head of the feed.
    await tester.enterText(find.byType(TextField), '生日');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(repository.queries.last.keyword, '生日');
  });

  testWidgets('wide dynamic filters keep a draft until applied or cancelled', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1000, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _StubRepository(pages: 1);
    await tester.pumpWidget(
      _app(repository, textScaler: const TextScaler.linear(2)),
    );
    await tester.pumpAndSettle();
    expect(find.text('筛选动态'), findsNothing);
    final initialRequests = repository.requests;

    await tester.tap(find.byTooltip('筛选与排序'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('筛选动态'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(AppButton, '视频'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, '视频'));
    await tester.ensureVisible(find.text('点赞最多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('点赞最多'));
    await tester.pumpAndSettle();
    expect(repository.requests, initialRequests);
    expect(find.text('筛选动态'), findsOneWidget);
    await tester.ensureVisible(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(repository.queries.last, const DynamicQuery());
    expect(find.text('筛选动态'), findsNothing);

    await tester.scrollUntilVisible(
      find.byTooltip('筛选与排序'),
      -300,
      scrollable: find
          .descendant(
            of: find.byKey(const PageStorageKey('historical-dynamics-feed')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('筛选与排序'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AppSegments<DynamicSort>>(
            find.byType(AppSegments<DynamicSort>),
          )
          .selected,
      DynamicSort.newest,
    );
    await tester.ensureVisible(find.widgetWithText(AppButton, '视频'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, '视频'));
    await tester.ensureVisible(find.text('点赞最多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('点赞最多'));
    await tester.ensureVisible(find.text('应用筛选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('应用筛选'));
    await tester.pumpAndSettle();
    expect(repository.requests, initialRequests + 1);
    expect(repository.queries.last.type, DynamicType.video);
    expect(repository.queries.last.sort, DynamicSort.likes);
    expect(find.text('筛选动态'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an external dynamic query replaces an open filter draft', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1000, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _StubRepository(pages: 1);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('筛选与排序'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, '视频'));
    final controller = ProviderScope.containerOf(
      tester.element(find.byType(ContentPage)),
    ).read(dynamicFeedControllerProvider);
    const external = DynamicQuery(
      keyword: '生日',
      type: DynamicType.image,
      sort: DynamicSort.oldest,
    );
    await controller.applyQuery(external);
    await tester.pumpAndSettle();
    expect(find.text('筛选动态'), findsOneWidget);
    expect(
      tester
          .widget<AppSegments<DynamicSort>>(
            find.byType(AppSegments<DynamicSort>),
          )
          .selected,
      DynamicSort.oldest,
    );
    await tester.ensureVisible(find.text('应用筛选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('应用筛选'));
    await tester.pumpAndSettle();
    expect(controller.state.query, external);
    expect(repository.queries.last, external);
    expect(find.text('筛选动态'), findsNothing);
  });

  testWidgets('dynamic date summaries retain years and exclusive end dates', (
    tester,
  ) async {
    final repository = _StubRepository(pages: 1);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    final controller = ProviderScope.containerOf(
      tester.element(find.byType(ContentPage)),
    ).read(dynamicFeedControllerProvider);
    final examples = [
      (
        DynamicQuery(
          from: DateTime.utc(2025, 1, 1),
          to: DateTime.utc(2025, 1, 2),
        ),
        '2025年1月1日',
      ),
      (
        DynamicQuery(
          from: DateTime.utc(2025, 1, 1),
          to: DateTime.utc(2026, 1, 2),
        ),
        '2025年1月1日–2026年1月1日',
      ),
      (DynamicQuery(from: DateTime.utc(2025, 1, 1)), '2025年1月1日 起'),
      (DynamicQuery(to: DateTime.utc(2026, 1, 2)), '至 2026年1月1日'),
    ];
    for (final (query, label) in examples) {
      await controller.applyQuery(query);
      await tester.pumpAndSettle();
      expect(find.text(label), findsOneWidget);
      expect(repository.queries.last.from, query.from);
      expect(repository.queries.last.to, query.to);
    }
  });

  testWidgets('a first page failure offers a retry', (tester) async {
    final repository = _StubRepository(failFirst: true, pages: 1);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.text('网络连接失败'), findsOneWidget);
    await tester.tap(find.widgetWithText(AppButton, '重试'));
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
