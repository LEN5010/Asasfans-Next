import '../helpers/library_fixture.dart';
import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/content/application/content_providers.dart';
import 'package:asasfans_next/features/content/domain/dynamic_repository.dart';
import 'package:asasfans_next/core/time/shanghai_date_provider.dart';
import 'package:asasfans_next/features/today/presentation/on_this_day_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

DynamicPost _post(String id, {String text = '往年正文'}) => DynamicPost(
  identity: ContentIdentity(source: ContentSource.bilibiliDynamic, value: id),
  member: const DynamicMember(id: 'uid:1', name: '嘉然今天吃什么'),
  type: DynamicType.image,
  text: text,
  images: const [],
  publishedAt: DateTime.utc(2021, 8, 16, 2, 52),
);

class _StubRepository implements DynamicRepository {
  _StubRepository({this.posts = const [], this.failure});

  final List<DynamicPost> posts;
  final ApiFailure? failure;
  int calls = 0;

  @override
  Future<List<DynamicPost>> onThisDay({
    String? monthDay,
    OnThisDaySort sort = OnThisDaySort.hot,
    int limit = 8,
  }) async {
    calls++;
    if (failure != null) throw failure!;
    return posts;
  }

  @override
  Future<DynamicPage> search({
    DynamicQuery query = const DynamicQuery(),
    String? cursor,
    RequestCancellation? cancellation,
  }) async => const DynamicPage(items: []);

  @override
  Future<List<DynamicMember>> members() async => const [];
}

Widget _app(DynamicRepository repository) => ProviderScope(
  overrides: [
    ...offlineLibrary(),
    dynamicRepositoryProvider.overrideWithValue(repository),
    currentTimeProvider.overrideWithValue(() => DateTime.utc(2026, 8, 16, 4)),
  ],
  child: const MaterialApp(home: Scaffold(body: OnThisDaySection())),
);

void main() {
  testWidgets('renders posts from earlier years in the module', (tester) async {
    await tester.pumpWidget(_app(_StubRepository(posts: [_post('1')])));
    await tester.pumpAndSettle();

    expect(find.text('历史上的今天'), findsOneWidget);
    expect(find.text('往年正文'), findsOneWidget);
    // The year label uses the source's Shanghai calendar.
    expect(find.textContaining('2021 年'), findsOneWidget);
  });

  testWidgets('a failing module retains its heading and retry', (tester) async {
    await tester.pumpWidget(
      _app(_StubRepository(failure: const ApiFailure(ApiFailureKind.offline))),
    );
    await tester.pumpAndSettle();

    expect(find.text('历史上的今天'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('网络连接失败'), findsOneWidget);
  });

  testWidgets('a failed module can be retried in place', (tester) async {
    final repository = _StubRepository(
      failure: const ApiFailure(ApiFailureKind.unavailable),
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    expect(repository.calls, 1);

    await tester.tap(find.widgetWithText(OutlinedButton, '重试'));
    await tester.pumpAndSettle();

    expect(repository.calls, 2);
  });

  testWidgets('an empty day reads as empty, not broken', (tester) async {
    await tester.pumpWidget(_app(_StubRepository()));
    await tester.pumpAndSettle();

    expect(find.text('往年今天还没有记录'), findsOneWidget);
    expect(find.text('重试'), findsNothing);
  });
}
