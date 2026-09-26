import 'package:asasfans_next/core/network/api_failure.dart';
import 'package:asasfans_next/features/content/application/content_providers.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/shared/widgets/app_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_fixture.dart';
import 'visual_harness.dart';

/// The fixture, until the test flips [failing]; with [pages] the first
/// answer promises a second page, and that page always fails.
class _Switchable implements FanartRepository {
  _Switchable({this.pages = false});
  final bool pages;
  var failing = false;

  @override
  Future<FanartPage> page({
    FanartQuery query = const FanartQuery(),
    String? cursor,
    RequestCancellation? cancellation,
  }) async {
    if (failing || cursor != null) {
      throw const ApiFailure(ApiFailureKind.offline);
    }
    return FanartPage(
      items: fixtureFanart,
      snapshotId: 'fixture',
      nextCursor: pages ? '1' : null,
    );
  }

  @override
  Future<FanartItem?> random({
    FanartQuery query = const FanartQuery(),
    RequestCancellation? cancellation,
  }) async => null;
}

/// R06/U18: every list state says what happened and what to do next, and
/// the states differ from one another.
void main() {
  setUpAll(Visual.setUp);
  const view = VisualView.phone;

  Future<void> pumpFanart(WidgetTester tester, FanartRepository repository) =>
      pumpVisualApp(
        tester,
        view: view,
        location: '/content/fanart',
        overrides: visualOverrides(
          extra: [fanartRepositoryProvider.overrideWithValue(repository)],
        ),
      );

  testVisual('nothing matches the applied conditions', (tester) async {
    await pumpFanart(tester, FixtureFanart(items: const []));
    expect(find.text('这里暂时还没有二创'), findsOneWidget);
    await tester.tap(find.text('嘉然').first);
    await settleVisual(tester);
    expect(find.text('没有符合条件的二创'), findsOneWidget);
    await shoot(tester, 'state-filtered-empty', view);
  });

  testVisual('a failed refresh keeps the last results and says so', (
    tester,
  ) async {
    final repository = _Switchable();
    await pumpFanart(tester, repository);
    repository.failing = true;
    await tester.runAsync(
      () => visualContainer(
        tester,
      ).read(fanartFeedControllerProvider(ContentChannel.fanart)).refresh(),
    );
    await settleVisual(tester);
    expect(find.textContaining('刷新失败，下面是上次加载的内容'), findsOneWidget);
    expect(find.widgetWithText(AppButton, '重试'), findsWidgets);
    await shoot(tester, 'state-stale', view);
  });

  testVisual('a failed next page keeps what loaded and retries in place', (
    tester,
  ) async {
    await pumpFanart(tester, _Switchable(pages: true));
    for (var i = 0; i < 12; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await settleVisual(tester);
    expect(find.textContaining('加载更多失败'), findsOneWidget);
    expect(find.widgetWithText(AppButton, '重试'), findsWidgets);
    await shoot(tester, 'state-tail-failed', view);
  });

  testVisual('the updates inbox says what it holds and when', (tester) async {
    await pumpVisualApp(tester, view: view, location: '/mine/updates');
    expect(find.text('由应用运行时检查得到，不是系统推送'), findsOneWidget);
    expect(find.textContaining('应用没有运行时不会收到'), findsOneWidget);
    await shoot(tester, 'state-updates-empty', view);
  });

  testVisual('an empty history says how things get there', (tester) async {
    await pumpVisualApp(tester, view: view, location: '/mine/history');
    expect(find.textContaining('打开过的作品'), findsOneWidget);
    await shoot(tester, 'state-history-empty', view);
  });
}
