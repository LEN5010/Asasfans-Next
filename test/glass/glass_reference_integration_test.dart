import 'package:asasfans_next/shared/widgets/glass/app_glass_navigation.dart';
import 'package:asasfans_next/shared/widgets/glass/app_glass_scope.dart';
import 'package:asasfans_next/shared/widgets/glass/app_glass_style.dart';
import 'package:asasfans_next/shared/widgets/glass/app_glass_surface.dart';
import 'package:asasfans_next/shared/widgets/glass/glass_policy.dart';
import 'package:asasfans_next/shared/widgets/glass/glass_runtime.dart';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  test('chrome retains reference tint and package optical defaults', () {
    const defaults = LiquidGlassSettings();
    for (final brightness in Brightness.values) {
      final settings = AppGlassStyle.settings(brightness);
      expect(settings.thickness, defaults.thickness);
      expect(settings.blur, defaults.blur);
      expect(settings.refractiveIndex, defaults.refractiveIndex);
      expect(settings.chromaticAberration, defaults.chromaticAberration);
      expect(
        settings.glassColor.a,
        closeTo(brightness == Brightness.dark ? .24 : .10, .001),
      );
    }
  });

  testWidgets('real child sits inside glass and survives clear round trips', (
    tester,
  ) async {
    final runtime = GlassRuntime(
      shaderFiltersSupported: true,
      load: () async {},
    );
    addTearDown(runtime.dispose);
    await runtime.prepare();
    final mode = ValueNotifier(GlassMaterialMode.liquid);
    addTearDown(mode.dispose);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => ValueListenableBuilder(
          valueListenable: mode,
          builder: (_, value, _) => AppGlassScope(
            runtime: runtime,
            mode: value,
            transparencyOverride: SystemTransparency.allowed,
            child: child!,
          ),
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: AppGlassSurface(child: TextField(focusNode: focus)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AdaptiveGlass),
        matching: find.byType(TextField),
      ),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), '输入仍在');
    final state = tester.state(find.byType(TextField));
    focus.requestFocus();
    await tester.pump();
    mode.value = GlassMaterialMode.clear;
    await tester.pumpAndSettle();
    expect(find.byType(AdaptiveGlass), findsNothing);
    expect(identical(tester.state(find.byType(TextField)), state), isTrue);
    expect(focus.hasFocus, isTrue);
    mode.value = GlassMaterialMode.liquid;
    await tester.pumpAndSettle();
    expect(identical(tester.state(find.byType(TextField)), state), isTrue);
    expect(find.text('输入仍在'), findsOneWidget);
    expect(focus.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'library selection is committed on release, not press or cancel',
    (tester) async {
      final runtime = GlassRuntime(
        shaderFiltersSupported: true,
        load: () async {},
      );
      addTearDown(runtime.dispose);
      await runtime.prepare();
      final toolsFocus = FocusNode();
      addTearDown(toolsFocus.dispose);
      final selections = <int>[];
      var opens = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => AppGlassScope(
            runtime: runtime,
            mode: GlassMaterialMode.liquid,
            transparencyOverride: SystemTransparency.allowed,
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: AppGlassNavigation(
                  selected: 0,
                  onSelect: selections.add,
                  onTools: () => opens++,
                  toolsFocus: toolsFocus,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      GlassTabBar bar() => tester.widget(find.byType(GlassTabBar));
      final listener = tester
          .widgetList<Listener>(
            find.ancestor(
              of: find.byType(GlassTabBar),
              matching: find.byType(Listener),
            ),
          )
          .firstWhere((l) => l.onPointerCancel != null);
      listener.onPointerDown!(
        const PointerDownEvent(pointer: 1, position: Offset(20, 20)),
      );
      bar().onTabSelected(1);
      await tester.pump();
      expect(selections, isEmpty);
      listener.onPointerUp!(const PointerUpEvent(pointer: 1));
      await tester.pumpAndSettle();
      expect(selections, [1]);

      listener.onPointerDown!(
        const PointerDownEvent(pointer: 2, position: Offset(20, 20)),
      );
      bar().onTabSelected(4);
      listener.onPointerCancel!(const PointerCancelEvent(pointer: 2));
      await tester.pumpAndSettle();
      expect(selections, [1]);

      // Dragging over Tools must neither select it nor open the panel.
      listener.onPointerDown!(
        const PointerDownEvent(pointer: 3, position: Offset(20, 20)),
      );
      listener.onPointerMove!(
        const PointerMoveEvent(pointer: 3, position: Offset(200, 20)),
      );
      listener.onPointerUp!(const PointerUpEvent(pointer: 3));
      bar().onTabSelected(2);
      await tester.pumpAndSettle();
      expect(opens, 0);
      expect(bar().selectedIndex, 0);

      // A later keyboard/accessibility activation is not poisoned by the drag.
      bar().onTabSelected(2);
      await tester.pumpAndSettle();
      expect(opens, 1);
      expect(bar().selectedIndex, 0);
      toolsFocus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(opens, 2);
      final semantics = tester.ensureSemantics();
      await tester.pumpAndSettle();
      final toolNode = tester.getSemantics(find.bySemanticsLabel('工具'));
      toolNode.owner!.performAction(toolNode.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(opens, 3);
      await tester.tapAt(tester.getCenter(find.byType(AppGlassNavigation)));
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(find.byType(AppGlassNavigation)));
      await tester.pumpAndSettle();
      expect(opens, 5);
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  for (final liquid in [false, true]) {
    testWidgets(
      '320px navigation honors 2x text (${liquid ? 'liquid' : 'clear'})',
      (tester) async {
        tester.view.physicalSize = const Size(320, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final runtime = GlassRuntime(
          shaderFiltersSupported: liquid,
          load: () async {},
        );
        addTearDown(runtime.dispose);
        await runtime.prepare();
        final focus = FocusNode();
        addTearDown(focus.dispose);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: AppGlassScope(
                runtime: runtime,
                mode: GlassMaterialMode.liquid,
                transparencyOverride: SystemTransparency.allowed,
                child: child!,
              ),
            ),
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: AppGlassNavigation(
                    selected: 0,
                    onSelect: (_) {},
                    onTools: () {},
                    toolsFocus: focus,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byType(AppGlassNavigation)).height, 84);
        final labels = find.text('今日');
        expect(labels, findsWidgets);
        for (final element in labels.evaluate()) {
          expect(MediaQuery.textScalerOf(element).scale(12), 24);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
