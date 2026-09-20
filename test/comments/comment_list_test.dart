import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/comments/application/comment_providers.dart';
import 'package:asasfans_next/features/comments/data/bili_comment_repository.dart';
import 'package:asasfans_next/features/comments/domain/comments.dart';
import 'package:asasfans_next/features/comments/presentation/comment_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/video_comment_fixture.dart';

void main() {
  late OfflineCommentRepository repository;
  setUp(() => repository = OfflineCommentRepository());
  Widget host() => ProviderScope(
    overrides: [commentRepositoryProvider.overrideWithValue(repository)],
    child: const MaterialApp(
      home: Scaffold(
        body: CommentList(query: CommentQuery(oid: fixtureAid)),
      ),
    ),
  );
  testWidgets(
    'normal root and subreplies page automatically, with no composer or like actions',
    (tester) async {
      repository.respond = (query, page, _) async {
        final raw = query.root == null
            ? {
                ...commentPagePayload(total: 1),
                'replies': [commentPayload(100, replies: 21)],
              }
            : commentPagePayload(page: page, root: query.root);
        return BiliCommentRepository.decode(raw, query, page);
      };
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expect(find.text('评论内容 100'), findsOneWidget);
      await tester.tap(find.text('查看 21 条回复'));
      await tester.pumpAndSettle();
      expect(find.text('评论回复'), findsOneWidget);
      expect(find.text('评论内容 100'), findsOneWidget);
      expect(repository.calls.last.query.root, '100');
      await tester.scrollUntilVisible(
        find.text('评论内容 2000'),
        700,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(
        repository.calls.where((c) => c.query.root == '100').map((c) => c.page),
        [1, 2],
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(Icons.thumb_up), findsNothing);
      expect(find.text('发送'), findsNothing);
    },
  );
  testWidgets('closed, empty, login and failed paging are distinct', (
    tester,
  ) async {
    repository.respond = (_, page, _) async =>
        CommentPage(page: page, total: 0, items: [], closed: true);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.text('评论区已关闭'), findsOneWidget);
    expect(find.text('还没有评论'), findsNothing);
    repository.respond = (_, _, _) async =>
        throw const ApiFailure(ApiFailureKind.loginRequired);
    await tester.tap(find.byTooltip('刷新评论'));
    await tester.pumpAndSettle();
    expect(find.text('登录 B 站'), findsOneWidget);
    expect(find.text('还没有评论'), findsNothing);
    repository.respond = (_, page, _) async =>
        CommentPage(page: page, total: 0, items: []);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('还没有评论'), findsOneWidget);
  });
  testWidgets('sorting clears old roots and sends a fresh first page', (
    tester,
  ) async {
    repository.respond = (query, page, _) async => CommentPage(
      page: page,
      total: 1,
      items: [commentFixture(query.order == CommentOrder.likes ? 1 : 2)],
    );
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.text('评论内容 1'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '最新'));
    await tester.pumpAndSettle();
    expect(find.text('评论内容 1'), findsNothing);
    expect(find.text('评论内容 2'), findsOneWidget);
    expect(repository.calls.last.page, 1);
    expect(repository.calls.last.query.order, CommentOrder.latest);
  });
}
