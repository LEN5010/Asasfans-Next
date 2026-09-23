import 'package:asasfans_next/features/mine/presentation/mine_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../helpers/preferences_fixture.dart';
import '../helpers/account_fixture.dart';

void main() {
  testWidgets(
    'phone uses grouped personal, persisted preferences and app settings',
    (tester) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [offlinePreferences(), offlineAccount()],
          child: const MaterialApp(home: MinePage()),
        ),
      );
      await tester.pumpAndSettle();
      // No sign-in from an earlier build on this device, so nothing to clear.
      expect(find.text('账号'), findsNothing);
      expect(find.text('我的内容'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('偏好'), 180);
      expect(find.text('偏好'), findsOneWidget);
      expect(find.text('订阅管理'), findsOneWidget);
      expect(find.text('主题'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('关于'), 180);
      expect(find.text('应用'), findsOneWidget);
      expect(find.byKey(const ValueKey('mine-sections')), findsNothing);
    },
  );

  testWidgets(
    'desktop settings use a master/detail selection and a real about page',
    (tester) async {
      tester.view
        ..physicalSize = const Size(1280, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [offlinePreferences(), offlineAccount()],
          child: const MaterialApp(home: MinePage()),
        ),
      );
      final sidebar = find.byKey(const ValueKey('mine-sections'));
      expect(sidebar, findsOneWidget);
      expect(find.text('订阅管理'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('订阅管理')).dx,
        greaterThan(tester.getRect(sidebar).right),
      );
      await tester.tap(find.descendant(of: sidebar, matching: find.text('应用')));
      await tester.pumpAndSettle();
      expect(find.text('订阅管理'), findsNothing);
      expect(find.text('关于'), findsOneWidget);
      await tester.tap(find.text('关于'));
      await tester.pumpAndSettle();
      expect(find.byType(LicensePage), findsOneWidget);
    },
  );

  testWidgets('a stored sign-in is only cleared after confirmation', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final vault = MemoryAccountVault()..value = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          offlinePreferences(),
          offlineAccount(vault: vault),
        ],
        child: const MaterialApp(home: MinePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('账号'), findsOneWidget);
    await tester.tap(find.text('清除本地 B 站登录信息'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(vault.value, isTrue);
    await tester.tap(find.text('清除本地 B 站登录信息'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(vault.value, isFalse);
    expect(find.text('账号'), findsNothing);
  });
}
