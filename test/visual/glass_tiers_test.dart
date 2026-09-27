import 'dart:ui' as ui;

import 'package:asasfans_next/features/content/presentation/content_page.dart';
import 'package:asasfans_next/features/content/presentation/fanart_card.dart';
import 'package:asasfans_next/features/handoff/presentation/anchor_restore.dart';
import 'package:asasfans_next/features/preferences/domain/app_preferences.dart';
import 'package:asasfans_next/features/today/presentation/today_page.dart';
import 'package:asasfans_next/shared/widgets/app_controls.dart';
import 'package:asasfans_next/shared/widgets/glass/app_glass_navigation.dart';
import 'package:asasfans_next/shared/widgets/glass/app_glass_scope.dart';
import 'package:asasfans_next/shared/widgets/glass/glass_policy.dart';
import 'package:asasfans_next/shared/widgets/media_card_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_harness.dart';

/// The same pages and the same actions at each glass tier: solid (流畅),
/// standard (自动, the default where tests run) and premium (视觉).
///
/// Run with `--enable-impeller` and each tier is drawn by Impeller on this
/// machine. Without it shaders are unsupported and every tier falls back to
/// solid: the actions are still checked, the images show no glass.
void main() {
  setUpAll(Visual.setUp);
  final phone = VisualView.phone.withSystemBars;
  const tiers = {
    GlassChoice.smooth: GlassTier.solid,
    GlassChoice.auto: GlassTier.standard,
    GlassChoice.visual: GlassTier.premium,
  };

  GlassTier drawn(WidgetTester tester) =>
      AppGlassScope.of(tester.element(find.byType(Scaffold).first)).tier;

  ScrollPosition feed(WidgetTester tester) => tester
      .stateList<ScrollableState>(
        find.descendant(
          of: find.byType(ContentPage),
          matching: find.byType(Scrollable),
        ),
      )
      .firstWhere((state) => state.axisDirection == AxisDirection.down)
      .position;

  /// The dock on a phone, the sidebar on a wide window. Liquid glass draws
  /// the selected label twice, once inside its lens.
  Finder navigation(String label) {
    final dock = find.byType(AppGlassNavigation);
    return find
        .descendant(
          of: dock.evaluate().isNotEmpty ? dock : find.byType(AppSidebar),
          matching: find.text(label),
        )
        .first;
  }

  for (final MapEntry(key: choice, value: tier) in tiers.entries) {
    for (final view in [
      phone,
      phone.dark,
      VisualView.wide,
      VisualView.wide.dark,
    ]) {
      testVisual('${tier.name} ${view.name}: same pages, same actions', (
        tester,
      ) async {
        await pumpVisualApp(
          tester,
          view: view,
          location: '/content/fanart',
          overrides: visualOverrides(
            preferences: const AppPreferences().withGlass(choice),
          ),
        );
        // The shaders load after the first frame.
        for (var i = 0; i < 20 && drawn(tester) != tier; i++) {
          await settleVisual(tester, rounds: 1);
        }
        expect(
          drawn(tester),
          ui.ImageFilter.isShaderFilterSupported ? tier : GlassTier.solid,
        );
        feed(tester).jumpTo(600);
        await settleVisual(tester, rounds: 3);
        final offset = feed(tester).pixels;
        expect(offset, greaterThan(0));
        await shoot(tester, 'glass-${tier.name}-fanart', view);

        // Away to Today and back: the feed is where it was.
        await tester.tap(navigation('今日'));
        await settleVisual(tester);
        expect(find.byType(TodayPage), findsOneWidget);
        await shoot(tester, 'glass-${tier.name}-today', view);
        await tester.tap(navigation('内容'));
        await settleVisual(tester);
        expect(feed(tester).pixels, offset);

        // A work's more menu opens, and nothing else.
        await tester.tap(
          find
              .descendant(
                of: find.byType(FanartCard),
                matching: find.byType(MediaMoreButton),
              )
              .hitTestable()
              .first,
        );
        await settleVisual(tester);
        final later = find.byWidgetPredicate(
          (w) => w is AppSwitch && w.label == '稍后看',
        );
        expect(later, findsOneWidget);
        Navigator.of(tester.element(later)).pop();
        await settleVisual(tester);

        final dock = find.byType(AppGlassNavigation);
        if (dock.evaluate().isEmpty) return;
        // On a phone: a notice above the dock, keyboard focus clear of it.
        showAnchorFallbackNotice(tester.element(find.byType(FanartCard).first));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        final top = tester.getRect(dock).top;
        expect(
          tester.getRect(find.byType(SnackBar)).bottom,
          lessThanOrEqualTo(top),
        );
        ScaffoldMessenger.of(
          tester.element(find.byType(FanartCard).first),
        ).removeCurrentSnackBar();
        await settleVisual(tester, rounds: 2);
        for (var i = 0; i < 30; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          final context = FocusManager.instance.primaryFocus?.context;
          if (context == null ||
              Scrollable.maybeOf(context, axis: Axis.vertical) == null) {
            continue;
          }
          final box = context.findRenderObject()! as RenderBox;
          final rect = box.localToGlobal(Offset.zero) & box.size;
          if (rect.height < top - view.safeArea.top) {
            expect(rect.bottom, lessThanOrEqualTo(top), reason: '$i');
          }
        }
      });
    }
  }

  // A clip per tier: the feed passing under the dock, then Today and back.
  // Frames are 16 ms apart in app time.
  for (final MapEntry(key: choice, value: tier) in tiers.entries) {
    for (final view in [phone, phone.dark]) {
      testVisual('${tier.name} ${view.name}: clip', (tester) async {
        await pumpVisualApp(
          tester,
          view: view,
          location: '/content/fanart',
          overrides: visualOverrides(
            preferences: const AppPreferences().withGlass(choice),
          ),
        );
        for (var i = 0; i < 20 && drawn(tester) != tier; i++) {
          await settleVisual(tester, rounds: 1);
        }
        final clip = 'clip-${tier.name}';
        var index = 0;
        Future<void> frames(int count) async {
          for (var i = 0; i < count; i++) {
            await tester.pump(const Duration(milliseconds: 16));
            await shootFrame(tester, clip, index++, view);
          }
        }

        final position = feed(tester);
        for (var i = 0; i < 60; i++) {
          position.jumpTo(
            (i * 14.0).clamp(0, position.maxScrollExtent).toDouble(),
          );
          await frames(1);
        }
        await tester.tap(navigation('今日'));
        await frames(24);
        await tester.tap(navigation('内容'));
        await frames(24);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
