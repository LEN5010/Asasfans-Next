import 'package:asasfans_next/app/asasfans_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/today_fixture.dart';

void main() {
  testWidgets(
    'phone navigation opens tools as an action, not a content branch',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: offlineTodayOverrides(),
          child: const AsasfansApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.tap(find.text('工具').last);
      await tester.pumpAndSettle();
      expect(find.text('录音棚'), findsOneWidget);
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('刷新今日'), findsOneWidget);
      expect(find.text('录音棚'), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );

  testWidgets('wide windows use the navigation rail', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: offlineTodayOverrides(),
        child: const AsasfansApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
  testWidgets(
    'Mine opens real rules management with source ordering as the default',
    (tester) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: offlineTodayOverrides(),
          child: const AsasfansApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('我的').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, '内容规则'));
      await tester.pumpAndSettle();
      expect(find.text('视频默认过滤'), findsOneWidget);
      expect(find.text('没有屏蔽规则'), findsOneWidget);
      expect(
        tester
            .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, '订阅优先'))
            .value,
        isFalse,
      );
    },
  );
}
