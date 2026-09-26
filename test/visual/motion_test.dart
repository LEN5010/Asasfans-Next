import 'package:asasfans_next/core/storage/storage_failure.dart';
import 'package:asasfans_next/features/content/presentation/fanart_card.dart';
import 'package:asasfans_next/features/content/presentation/fanart_detail_page.dart';
import 'package:asasfans_next/features/library/application/library_providers.dart';
import 'package:asasfans_next/features/library/data/sqlite_library_repository.dart';
import 'package:asasfans_next/features/library/domain/library_models.dart';
import 'package:asasfans_next/shared/widgets/app_controls.dart';
import 'package:asasfans_next/shared/widgets/media_cover.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_fixture.dart';
import 'visual_harness.dart';

/// Refuses to store 稍后看, as a full disk or a locked database would.
class _Refusing extends SqliteLibraryRepository {
  _Refusing() : super(MemoryLocalDatabase(), backgroundDecoding: false);
  @override
  Future<void> setLater(ContentSnapshot item, bool later) async =>
      throw const StorageFailure(StorageFailureKind.unavailable);
}

/// R07/U20: the relationships between a control and what it changes. Each
/// is checked for what it does (geometry and state at defined moments), not
/// only drawn; and each has a reduced-motion form that says the same.
void main() {
  setUpAll(Visual.setUp);
  const view = VisualView.phone;

  Finder heroTile() => find.byWidgetPredicate(
    (widget) =>
        widget is FanartCard &&
        widget.heroTag != null &&
        widget.item.images.isNotEmpty &&
        widget.item.contentType.name == 'image',
  );

  Future<void> openFirstImageWork(WidgetTester tester) async {
    await pumpVisualApp(tester, view: view, location: '/content/fanart');
    await tester.tap(
      find.descendant(of: heroTile().first, matching: find.byType(MediaCover)),
    );
    // One frame into the route transition.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
  }

  testVisual('a work opens as its picture moving into the detail', (
    tester,
  ) async {
    await openFirstImageWork(tester);
    // Mid-flight the tile's art has left the grid for the flight overlay.
    expect(
      find.descendant(of: heroTile().first, matching: find.byType(MediaCover)),
      findsNothing,
    );
    await shoot(tester, 'motion-detail-mid', view);
    await settleVisual(tester);
    expect(find.byType(FanartDetailPage), findsOneWidget);
    // And back: the picture returns to the same tile.
    await tester.tap(find.byTooltip('返回'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      find.descendant(of: heroTile().first, matching: find.byType(MediaCover)),
      findsNothing,
    );
    await settleVisual(tester);
    expect(
      find.descendant(of: heroTile().first, matching: find.byType(MediaCover)),
      findsOneWidget,
    );
  });

  testVisual('with reduced motion the detail simply appears', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpVisualApp(tester, view: view, location: '/content/fanart');
    // The page route is already instant under reduced motion, so whether a
    // flight would run cannot be seen in the frames; the switch itself is
    // checked instead: both ends of the link are turned off.
    HeroMode modeOf(Finder hero) => tester.widget<HeroMode>(
      find.ancestor(of: hero, matching: find.byType(HeroMode)).first,
    );
    final tileHero = find.descendant(
      of: heroTile().first,
      matching: find.byType(Hero),
    );
    expect(modeOf(tileHero).enabled, isFalse);
    await tester.tap(
      find.descendant(of: heroTile().first, matching: find.byType(MediaCover)),
    );
    await settleVisual(tester);
    expect(find.byType(FanartDetailPage), findsOneWidget);
    final detailHero = find.descendant(
      of: find.byType(FanartDetailPage),
      matching: find.byType(Hero),
    );
    expect(modeOf(detailHero).enabled, isFalse);
  });

  testVisual('the filter panel returns focus to its entry, and the line '
      'marks what it changed', (tester) async {
    await pumpVisualApp(tester, view: view, location: '/content/fanart');
    // Keyboard focus on the entry, and open it from the keyboard.
    final entry = find.byTooltip('筛选');
    Focus.of(
      tester.element(
        find.descendant(of: entry, matching: find.byType(Icon)).first,
      ),
    ).requestFocus();
    await tester.pump();
    final focused = FocusManager.instance.primaryFocus;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleVisual(tester);
    expect(find.text('应用筛选'), findsOneWidget);
    await tester.tap(find.widgetWithText(AppChoice, '手书·动画').last);
    await tester.tap(find.widgetWithText(AppButton, '应用筛选'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    // Just after closing: the new condition is tinted in the summary line.
    Color tint() {
      final box = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.byTooltip('移除“手书·动画”'),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      return (box.decoration as BoxDecoration).color ?? Colors.transparent;
    }

    expect(tint().a, greaterThan(0));
    await shoot(tester, 'motion-filter-applied', view);
    // The first page of the new query lands meanwhile, rebuilding the line;
    // the tint carries on rather than snapping off.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 150));
    expect(tint().a, greaterThan(0));
    await settleVisual(tester);
    // It settles to the plain line.
    expect(tint().a, 0);
    // And the keyboard is back where it was.
    expect(FocusManager.instance.primaryFocus, focused);
  });

  testVisual('a save says it is stored, and never before', (tester) async {
    await pumpVisualApp(tester, view: view, location: '/content/fanart');
    await tester.longPress(find.byType(FanartCard).first);
    await settleVisual(tester);
    expect(find.text('已加入稍后看'), findsNothing);
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is AppSwitch && widget.label == '稍后看',
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await settleVisual(tester);
    expect(find.text('已加入稍后看'), findsOneWidget);
    await shoot(tester, 'motion-save-done', view);
  });

  testVisual('a save that fails says so and shows no success', (tester) async {
    await pumpVisualApp(
      tester,
      view: view,
      location: '/content/fanart',
      overrides: visualOverrides(
        extra: [libraryRepositoryProvider.overrideWithValue(_Refusing())],
      ),
    );
    await tester.longPress(find.byType(FanartCard).first);
    await settleVisual(tester);
    final later = find.byWidgetPredicate(
      (widget) => widget is AppSwitch && widget.label == '稍后看',
    );
    await tester.tap(later);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await settleVisual(tester);
    expect(find.text('本地资料暂时无法读写，请重试'), findsOneWidget);
    expect(find.text('已加入稍后看'), findsNothing);
    expect(tester.widget<AppSwitch>(later).value, isFalse);
  });
}
