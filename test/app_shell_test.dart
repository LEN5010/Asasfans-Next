import 'package:asasfans_next/app/asasfans_app.dart';
import 'package:asasfans_next/shared/theme/app_icons.dart';
import 'package:asasfans_next/shared/widgets/glass/app_glass_navigation.dart';
import 'package:asasfans_next/features/mine/presentation/mine_page.dart';
import 'package:asasfans_next/shared/widgets/app_controls.dart';
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
      expect(find.byType(AppGlassNavigation), findsOneWidget);
      await tester.tap(find.byIcon(AppIcons.tools));
      await tester.pumpAndSettle();
      expect(find.text('录音棚'), findsOneWidget);
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('刷新今日'), findsOneWidget);
      expect(find.text('录音棚'), findsNothing);
      expect(find.byType(AppGlassNavigation), findsOneWidget);
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
    expect(find.byType(AppSidebar), findsOneWidget);
    expect(find.byType(AppGlassNavigation), findsNothing);
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
      await tester.scrollUntilVisible(
        find.widgetWithText(AppButton, '内容规则'),
        180,
        // Other branches keep their scrollables mounted offstage.
        scrollable: find
            .descendant(
              of: find.byType(MinePage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, '内容规则'));
      await tester.pumpAndSettle();
      // Built-in video filtering was silenced in c77045c; the page now opens
      // on the user's own rules.
      expect(find.byTooltip('添加规则'), findsOneWidget);
      expect(find.text('没有屏蔽规则'), findsOneWidget);
      expect(
        tester
            .widget<Switch>(
              find.descendant(
                of: find.widgetWithText(ListTile, '订阅优先'),
                matching: find.byType(Switch),
              ),
            )
            .value,
        isFalse,
      );
    },
  );
}
