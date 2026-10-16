import 'package:asasfans_next/app/asasfans_app.dart';
import 'package:asasfans_next/shared/theme/app_icons.dart';
import 'package:asasfans_next/shared/widgets/glass/app_glass_navigation.dart';
import 'package:asasfans_next/features/mine/presentation/mine_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/today_fixture.dart';
import 'helpers/preferences_fixture.dart';
import 'package:asasfans_next/features/preferences/domain/app_preferences.dart';

void main() {
  testWidgets('five tabs and tools fit 360px at double text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var selected = -1;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [offlinePreferences(const AppPreferences())],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: AppGlassNavigation(
                    selected: 0,
                    onSelect: (i) => selected = i,
                    onTools: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final label in ['今日', '内容', '音乐', '日历', '我的']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('音乐'));
    await tester.pump();
    expect(selected, 2);
    expect(tester.takeException(), isNull);
  });

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
        find.text('内容规则'),
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
      await tester.tap(find.text('内容规则'));
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
