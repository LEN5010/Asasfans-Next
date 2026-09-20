import 'dart:async';

import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/features/rules/application/rules_controller.dart';
import 'package:asasfans_next/features/rules/application/visible_random.dart';
import 'package:asasfans_next/features/rules/data/sqlite_rules_repository.dart';
import 'package:asasfans_next/features/rules/domain/content_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_fixture.dart';

class _Source implements FanartRepository {
  int calls = 0;
  int visibleAt = 2;
  ApiFailure? failure;
  Completer<FanartItem?>? delayed;
  @override
  Future<FanartItem?> random({
    FanartQuery query = const FanartQuery(),
    RequestCancellation? cancellation,
  }) async {
    calls++;
    if (failure != null) throw failure!;
    if (delayed != null) return delayed!.future;
    return FanartItem(
      identity: ContentIdentity(
        source: ContentSource.bilibiliDynamic,
        value: '$calls',
      ),
      text: calls < visibleAt ? 'blocked' : 'visible',
      authorName: 'name',
      authorUid: '123',
      images: const [],
      kind: FanartKind.fanart,
      contentType: FanartContentType.text,
      category: FanartCategory.normal,
      characterTags: const [],
    );
  }

  @override
  Future<FanartPage> page({
    FanartQuery query = const FanartQuery(),
    String? cursor,
    RequestCancellation? cancellation,
  }) => throw UnimplementedError();
}

void main() {
  late MemoryLocalDatabase db;
  late SqliteRulesRepository rules;
  late RulesController controller;
  late StreamController<int> changes;
  setUp(() async {
    db = MemoryLocalDatabase();
    rules = SqliteRulesRepository(db);
    changes = StreamController<int>();
    await rules.save(const RuleDraft(kind: RuleKind.word, value: 'blocked'));
    controller = RulesController(rules, changes.stream);
    await controller.ready();
  });
  tearDown(() async {
    controller.dispose();
    await changes.close();
    await rules.close();
    await db.close();
  });
  test('random skips blocked candidates with at most four draws', () async {
    final source = _Source();
    final result = await drawVisibleFanart(
      source,
      controller,
      query: const FanartQuery(),
      cancellation: RequestCancellation(),
    );
    expect(result.item!.text, 'visible');
    expect(source.calls, 2);
    final blocked = _Source()..visibleAt = 100;
    final exhausted = await drawVisibleFanart(
      blocked,
      controller,
      query: const FanartQuery(),
      cancellation: RequestCancellation(),
    );
    expect(exhausted.filtered, isTrue);
    expect(exhausted.item, isNull);
    expect(blocked.calls, 4);
  });
  test(
    'rate limiting or disposal does not become a blocked-result retry loop',
    () async {
      final source = _Source()
        ..failure = const ApiFailure(ApiFailureKind.rateLimited);
      await expectLater(
        drawVisibleFanart(
          source,
          controller,
          query: const FanartQuery(),
          cancellation: RequestCancellation(),
        ),
        throwsA(isA<ApiFailure>()),
      );
      expect(source.calls, 1);
      final delayed = _Source()..delayed = Completer<FanartItem?>();
      final cancellation = RequestCancellation();
      final result = drawVisibleFanart(
        delayed,
        controller,
        query: const FanartQuery(),
        cancellation: cancellation,
      );
      await Future<void>.delayed(Duration.zero);
      cancellation.cancel();
      delayed.delayed!.complete(null);
      await expectLater(
        result,
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.cancelled,
          ),
        ),
      );
      expect(delayed.calls, 1);
    },
  );
}
