import 'dart:async';
import 'dart:typed_data';

import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/content/application/content_providers.dart';
import 'package:asasfans_next/features/content/data/dynamic_fanart_repository.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/features/content/presentation/fanart_card.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  RequestOptions? request;
  String response = '{"id":"feedback-1"}';
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      response,
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Feedback implements FanartFeedbackRepository {
  final pending = Completer<void>();
  int submissions = 0;
  @override
  Future<void> submit({
    required ContentIdentity identity,
    required FanartFeedbackReason reason,
    required String detail,
  }) {
    submissions++;
    expect(identity, _item.identity);
    expect(reason, FanartFeedbackReason.wrongCharacter);
    expect(detail, '实际是嘉然');
    return pending.future;
  }
}

const _item = FanartItem(
  identity: ContentIdentity(
    source: ContentSource.bilibiliDynamic,
    value: '697635970322792467',
  ),
  text: '作品',
  authorName: '作者',
  authorUid: '123',
  images: [],
  kind: FanartKind.fanart,
  contentType: FanartContentType.text,
  category: FanartCategory.normal,
  characterTags: [],
);

void main() {
  test(
    'anonymous feedback preserves source IDs and uses the existing reason/detail contract',
    () async {
      final adapter = _Adapter();
      final dio = Dio(
        BaseOptions(baseUrl: 'https://example.test/dynamics/api/'),
      )..httpClientAdapter = adapter;
      final repository = DynamicFanartFeedbackRepository(dio);
      await repository.submit(
        identity: _item.identity,
        reason: FanartFeedbackReason.wrongCharacter,
        detail: ' 实际是嘉然 ',
      );
      expect(adapter.request!.method, 'POST');
      expect(adapter.request!.uri.path, '/dynamics/api/feedback');
      expect(adapter.request!.data, {
        'targetType': 'fanart',
        'targetId': '697635970322792467',
        'reason': 'wrong_category',
        'detail': '人物识别错误\n实际是嘉然',
      });
      expect(
        adapter.request!.headers.keys.map((key) => key.toLowerCase()),
        isNot(contains('cookie')),
      );
      await repository.submit(
        identity: const ContentIdentity(
          source: ContentSource.doubanTopic,
          value: '123',
        ),
        reason: FanartFeedbackReason.other,
        detail: '',
      );
      expect((adapter.request!.data as Map)['targetId'], 'douban:123');
      adapter.response = '{}';
      await expectLater(
        repository.submit(
          identity: _item.identity,
          reason: FanartFeedbackReason.contentIssue,
          detail: '',
        ),
        throwsA(isA<ApiFailure>()),
      );
    },
  );

  testWidgets(
    'the card question mark opens feedback without opening the work and submits once',
    (tester) async {
      final feedback = _Feedback();
      var opens = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fanartFeedbackRepositoryProvider.overrideWithValue(feedback),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 240,
                child: FanartCard(item: _item, onTap: () => opens++),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('反馈问题'));
      await tester.pumpAndSettle();
      expect(opens, 0);
      expect(find.text('人物识别错误'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '实际是嘉然');
      await tester.tap(find.text('提交'));
      await tester.pump();
      await tester.tap(find.text('提交'));
      expect(feedback.submissions, 1);
      feedback.pending.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('反馈已提交'), findsOneWidget);
    },
  );
}
