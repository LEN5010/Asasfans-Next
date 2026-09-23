import 'dart:async';

import 'package:asasfans_next/core/platform/transparency_preference.dart';
import 'package:asasfans_next/shared/widgets/glass/app_glass_scope.dart';
import 'package:asasfans_next/shared/widgets/glass/app_glass_surface.dart';
import 'package:asasfans_next/shared/widgets/glass/app_glass_navigation.dart';
import 'package:asasfans_next/shared/widgets/glass/glass_policy.dart';
import 'package:asasfans_next/shared/widgets/glass/glass_runtime.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/glass/probe_app.dart';

class _Signal implements TransparencyPreferenceService {
  final controller = StreamController<bool?>.broadcast();
  @override
  Stream<bool?> watch() => controller.stream;
}

void main() {
  testWidgets(
    'benchmark records background interruption without waiting for a frame',
    (tester) async {
      final runtime = GlassRuntime(
        shaderFiltersSupported: false,
        load: () async {},
      );
      addTearDown(runtime.dispose);
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      await tester.pumpWidget(GlassProbeApp(runtime: runtime));
      await tester.pumpAndSettle();
      final scene = tester.state<GlassProbeSceneState>(
        find.byType(GlassProbeScene),
      );
      scene.collecting = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(scene.invalidReasons, contains('application_inactive'));
      scene.didChangeMetrics();
      expect(scene.invalidReasons, contains('window_metrics_changed'));
      scene.collecting = false;
    },
  );

  testWidgets(
    'native content never instantiates glass even with a ready runtime',
    (tester) async {
      final runtime = GlassRuntime(
        shaderFiltersSupported: true,
        load: () async {},
      );
      addTearDown(runtime.dispose);
      await runtime.prepare();
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => AppGlassScope(
            runtime: runtime,
            mode: GlassMaterialMode.liquid,
            transparencyOverride: SystemTransparency.allowed,
            child: child!,
          ),
          home: const Scaffold(
            body: AppGlassSurface(
              nativeContent: true,
              child: Text('native-safe'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('native-safe'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('lifecycle changes stop motion even under explicit clear mode', (
    tester,
  ) async {
    final runtime = GlassRuntime(
      shaderFiltersSupported: false,
      load: () async {},
    );
    addTearDown(runtime.dispose);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => AppGlassScope(
          runtime: runtime,
          mode: GlassMaterialMode.clear,
          child: child!,
        ),
        home: Builder(
          builder: (context) =>
              Text('animate=${AppGlassScope.of(context).canAnimate}'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('animate=true'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(find.text('animate=false'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('animate=true'), findsOneWidget);
  });

  testWidgets(
    'refraction comparison refuses to export a solid fallback as proof',
    (tester) async {
      final runtime = GlassRuntime(
        shaderFiltersSupported: false,
        load: () async {},
      );
      addTearDown(runtime.dispose);
      await tester.pumpWidget(GlassProbeApp(runtime: runtime));
      await tester.pumpAndSettle();
      await tester.tap(find.text('折射 A/B 对照'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存渲染对照'));
      await tester.pumpAndSettle();
      expect(find.text('当前是清晰回退，不能作为折射证据。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('clear mode neither waits for system signal nor loads shaders', (
    tester,
  ) async {
    var loads = 0;
    final signal = _Signal();
    final runtime = GlassRuntime(
      shaderFiltersSupported: true,
      load: () async {
        loads++;
      },
    );
    addTearDown(runtime.dispose);
    addTearDown(signal.controller.close);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => AppGlassScope(
          runtime: runtime,
          mode: GlassMaterialMode.clear,
          transparency: signal,
          child: child!,
        ),
        home: const Scaffold(body: AppGlassSurface(child: Text('usable'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('usable'), findsOneWidget);
    expect(loads, 0);
    expect(find.byType(BackdropFilter), findsNothing);
  });
  testWidgets(
    'system transparency changes arrive above root dialog without losing input',
    (tester) async {
      final signal = _Signal();
      final runtime = GlassRuntime(
        shaderFiltersSupported: false,
        load: () async {},
      );
      addTearDown(runtime.dispose);
      addTearDown(signal.controller.close);
      final mode = ValueNotifier(GlassMaterialMode.liquid);
      addTearDown(mode.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => ValueListenableBuilder(
            valueListenable: mode,
            builder: (_, value, _) => AppGlassScope(
              runtime: runtime,
              mode: value,
              transparency: signal,
              child: child!,
            ),
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => Dialog(
                    child: AppGlassSurface(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(AppGlassScope.of(context).fallback.name),
                          const TextField(),
                        ],
                      ),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      signal.controller.add(false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '保留输入');
      final element = tester.element(find.byType(TextField));
      signal.controller.add(true);
      await tester.pumpAndSettle();
      expect(find.text('reducedTransparency'), findsOneWidget);
      mode.value = GlassMaterialMode.clear;
      await tester.pumpAndSettle();
      expect(
        identical(element, tester.element(find.byType(TextField))),
        isTrue,
      );
      expect(find.text('保留输入'), findsOneWidget);
      expect(find.text('userChoice'), findsOneWidget);
    },
  );
  testWidgets(
    'three-scene probe keeps Tools an action and excludes it from drag dispatch',
    (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final runtime = GlassRuntime(
        shaderFiltersSupported: false,
        load: () async {},
      );
      addTearDown(runtime.dispose);
      await tester.pumpWidget(GlassProbeApp(runtime: runtime));
      await tester.pumpAndSettle();
      final navigation = find.byType(AppGlassNavigation);
      final center = tester.getCenter(navigation);
      await tester.dragFrom(
        Offset(tester.getTopLeft(navigation).dx + 30, center.dy),
        const Offset(235, 0),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<AppGlassNavigation>(navigation).selected, 0);
      expect(find.text('工具面板 · 离线原型'), findsNothing);
      await tester.tap(find.text('工具'));
      await tester.pumpAndSettle();
      expect(find.text('工具面板 · 离线原型'), findsOneWidget);
      await tester.tap(find.byTooltip('关闭面板'));
      await tester.pumpAndSettle();
      expect(tester.widget<AppGlassNavigation>(navigation).selected, 0);
      expect(
        tester.widget<AppGlassNavigation>(navigation).toolsFocus.hasFocus,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
