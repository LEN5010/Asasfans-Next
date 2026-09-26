import 'dart:async';

import 'package:asasfans_next/app/asasfans_app.dart';
import 'package:asasfans_next/app/glass_providers.dart';
import 'package:asasfans_next/app/router/app_router.dart';
import 'package:asasfans_next/features/preferences/application/preferences_controller.dart';
import 'package:asasfans_next/features/preferences/domain/app_preferences.dart';
import 'package:asasfans_next/features/mine/presentation/mine_page.dart';
import 'package:asasfans_next/features/today/presentation/today_page.dart';
import 'package:asasfans_next/features/tools/presentation/tools_sheet.dart';
import 'package:asasfans_next/shared/theme/app_icons.dart';
import 'package:asasfans_next/shared/widgets/glass/app_glass_navigation.dart';
import 'package:asasfans_next/shared/widgets/glass/app_glass_scope.dart';
import 'package:asasfans_next/shared/widgets/glass/glass_policy.dart';
import 'package:asasfans_next/shared/widgets/glass/glass_runtime.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/preferences_fixture.dart';
import 'helpers/today_fixture.dart';

class _LoadingPreferences extends MemoryPreferencesRepository {
  final initial = Completer<AppPreferences>();
  @override
  Future<AppPreferences> load() => initial.future;
}

void main() {
  testWidgets('saved clear preference never starts a liquid first frame', (
    tester,
  ) async {
    final repository = _LoadingPreferences();
    var loads = 0;
    final runtime = GlassRuntime(
      shaderFiltersSupported: true,
      load: () async {
        loads++;
      },
    );
    addTearDown(runtime.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...offlineTodayOverrides(preferences: repository),
          glassRuntimeProvider.overrideWithValue(runtime),
        ],
        child: const AsasfansApp(),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<AppGlassScope>(find.byType(AppGlassScope)).mode,
      GlassMaterialMode.clear,
    );
    repository.initial.complete(
      const AppPreferences(material: AppMaterial.clear),
    );
    await tester.pumpAndSettle();
    expect(loads, 0);
    expect(
      tester.widget<AppGlassScope>(find.byType(AppGlassScope)).mode,
      GlassMaterialMode.clear,
    );
  });

  testWidgets(
    'theme/material and compact-wide changes retain the active page and scroll state',
    (tester) async {
      tester.view.physicalSize = const Size(390, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: offlineTodayOverrides(),
          child: const AsasfansApp(),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AsasfansApp)),
        listen: false,
      );
      await tester.pumpAndSettle();
      final today = tester.state(find.byType(TodayPage));
      final scrollable = find
          .descendant(
            of: find.byKey(const PageStorageKey('today-scroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      final scroll = tester.state<ScrollableState>(scrollable);
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final oldPixels = scroll.position.pixels;
      final prefs = container.read(preferencesControllerProvider.notifier);
      await prefs.setMaterial(AppMaterial.clear);
      await prefs.setAppearance(AppAppearance.dark);
      await tester.pumpAndSettle();
      expect(identical(today, tester.state(find.byType(TodayPage))), isTrue);
      expect(scroll.position.pixels, oldPixels);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      tester.view.physicalSize = const Size(1280, 568);
      await tester.pumpAndSettle();
      expect(find.byType(AppSidebar), findsOneWidget);
      expect(find.byType(AppGlassNavigation), findsNothing);
      expect(identical(today, tester.state(find.byType(TodayPage))), isTrue);
      expect(
        identical(scroll, tester.state<ScrollableState>(scrollable)),
        isTrue,
      );
      tester.view.physicalSize = const Size(390, 568);
      await tester.pumpAndSettle();
      expect(find.byType(AppGlassNavigation), findsOneWidget);
      expect(identical(today, tester.state(find.byType(TodayPage))), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'glass choices change the effective tier without rebuilding pages',
    (tester) async {
      // The system transparency signal: explicitly not reduced.
      const state = MethodChannel('asasfans.next/reduce_transparency_state');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        state,
        (_) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          state,
          null,
        ),
      );
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final runtime = GlassRuntime(
        shaderFiltersSupported: true,
        load: () async {},
      );
      addTearDown(runtime.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...offlineTodayOverrides(),
            glassRuntimeProvider.overrideWithValue(runtime),
          ],
          child: const AsasfansApp(),
        ),
      );
      await tester.pumpAndSettle();
      GlassPolicy policy() =>
          AppGlassScope.of(tester.element(find.byType(TodayPage)));
      // Android's automatic choice is the standard tier, not premium.
      expect(policy().tier, GlassTier.standard);
      final today = tester.state(find.byType(TodayPage));
      final prefs = ProviderScope.containerOf(
        tester.element(find.byType(AsasfansApp)),
        listen: false,
      ).read(preferencesControllerProvider.notifier);
      await prefs.setGlass(GlassChoice.visual);
      await tester.pumpAndSettle();
      expect(policy().tier, GlassTier.premium);
      await prefs.setGlass(GlassChoice.smooth);
      await tester.pumpAndSettle();
      expect(policy().tier, GlassTier.solid);
      expect(policy().fallback, GlassFallback.userChoice);
      expect(identical(today, tester.state(find.byType(TodayPage))), isTrue);

      // The settings page says what is in effect and why.
      await tester.tap(find.text('我的').last);
      await tester.pumpAndSettle();
      final mine = find
          .descendant(
            of: find.byType(MinePage),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(find.text('设置'), 200, scrollable: mine);
      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('当前：'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(SettingsPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('当前：实底界面（流畅优先，不采样背景）'), findsOneWidget);
      await tester.ensureVisible(find.text('视觉优先'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('视觉优先'));
      await tester.pumpAndSettle();
      expect(find.text('当前：精细玻璃'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('desktop sidebar remains in the accessible route tree', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: offlineTodayOverrides(),
        child: const AsasfansApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('工具'), findsOneWidget);
    expect(find.bySemanticsLabel('我的'), findsOneWidget);
    semantics.dispose();
  });

  for (final width in [320.0, 768.0, 840.0, 1280.0]) {
    testWidgets(
      'real shell at $width and 2x type has usable Tools and no overflow',
      (tester) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          ProviderScope(
            overrides: offlineTodayOverrides(),
            child: const AsasfansApp(),
          ),
        );
        await tester.pumpAndSettle();
        final navigation = width < 840
            ? find.byType(AppGlassNavigation)
            : find.byType(AppSidebar);
        await tester.tap(
          find.descendant(
            of: navigation,
            matching: find.byIcon(AppIcons.tools),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ToolsSheet), findsOneWidget);
        expect(
          find.byType(Dialog),
          width >= 840 ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(BottomSheet),
          width < 840 ? findsOneWidget : findsNothing,
        );
        await tester.tap(find.byTooltip('关闭'));
        await tester.pumpAndSettle();
        expect(find.byType(ToolsSheet), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('subpages and keyboard do not keep a blocking floating bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: offlineTodayOverrides(),
        child: const AsasfansApp(),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AsasfansApp)),
      listen: false,
    );
    await tester.pumpAndSettle();
    container.read(appRouterProvider).go('/mine/backup');
    await tester.pumpAndSettle();
    expect(find.byType(AppGlassNavigation), findsNothing);
    expect(find.text('备份与恢复'), findsOneWidget);
    container.read(appRouterProvider).go('/mine');
    await tester.pumpAndSettle();
    expect(find.byType(AppGlassNavigation), findsOneWidget);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(find.byType(AppGlassNavigation), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
