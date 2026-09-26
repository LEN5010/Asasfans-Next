import 'package:asasfans_next/features/mine/presentation/mine_page.dart';
import 'package:asasfans_next/features/tools/presentation/tools_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../helpers/preferences_fixture.dart';
import '../helpers/account_fixture.dart';
import '../helpers/library_fixture.dart';
import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/features/library/application/library_providers.dart';
import 'package:asasfans_next/features/library/domain/library_models.dart';
import 'package:asasfans_next/features/preferences/presentation/preferences_controls.dart';

void main() {
  testWidgets(
    'phone leads with my own content; settings and management come after',
    (tester) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [offlinePreferences(), ...offlineLibrary()],
          child: const MaterialApp(home: MinePage()),
        ),
      );
      await tester.pumpAndSettle();
      // No sign-in from an earlier build on this device, so nothing to clear.
      expect(find.text('账号'), findsNothing);
      expect(find.text('我的内容'), findsOneWidget);
      // The library entries are the first thing below the title, all
      // within the first screen.
      for (final entry in ['收藏', '稍后看', '历史记录', '继续观看', '时间书签']) {
        expect(tester.getRect(find.text(entry)).bottom, lessThan(844));
      }
      expect(
        tester.getTopLeft(find.text('收藏')).dy,
        lessThan(tester.getTopLeft(find.text('订阅管理')).dy),
      );
      // Preferences moved to their own page; the root holds no form.
      expect(find.text('主题'), findsNothing);
      await tester.scrollUntilVisible(find.text('关于'), 180);
      expect(find.text('设置'), findsOneWidget);
      expect(find.text('应用'), findsOneWidget);
      // The tools are reachable by name, not only by the floating button.
      await tester.ensureVisible(find.text('工具与相关站点'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('工具与相关站点'));
      await tester.pumpAndSettle();
      expect(find.byType(ToolsSheet), findsOneWidget);
    },
  );

  testWidgets('settings keep every preference control on their own page', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [offlinePreferences(), ...offlineLibrary()],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('主题'), findsOneWidget);
    expect(find.byType(PreferencesControls), findsOneWidget);
  });

  testWidgets('wide windows keep one centred column and a real about page', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1280, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [offlinePreferences(), ...offlineLibrary()],
        child: const MaterialApp(home: MinePage()),
      ),
    );
    await tester.pumpAndSettle();
    // Not stretched: the page reads as a column, with every library entry
    // on one row.
    final saved = tester.getRect(find.text('收藏'));
    final updates = tester.getRect(find.text('应用内更新'));
    expect(saved.top, updates.top);
    expect(updates.right - saved.left, lessThan(900));
    await tester.scrollUntilVisible(find.text('关于'), 180);
    await tester.tap(find.text('关于'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('recent history appears once there is some', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [offlinePreferences(), ...offlineLibrary()],
        child: const MaterialApp(home: MinePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('最近浏览'), findsNothing);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MinePage)),
    );
    await tester.runAsync(
      () => container
          .read(libraryRepositoryProvider)
          .recordHistory(
            const ContentSnapshot(
              identity: ContentIdentity(
                source: ContentSource.bilibiliVideo,
                value: 'BV1recent',
              ),
              title: '最近看过的视频',
              body: '',
              authorName: '作者',
              kind: LibraryMediaKind.video,
            ),
            HistoryAction.external,
          ),
    );
    await tester.pumpAndSettle();
    expect(find.text('最近浏览'), findsOneWidget);
    expect(find.text('最近看过的视频'), findsOneWidget);
  });

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
          ...offlineLibrary(account: offlineAccount(vault: vault)),
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
