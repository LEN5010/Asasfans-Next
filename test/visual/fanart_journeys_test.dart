import 'package:asasfans_next/app/providers.dart';
import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/core/platform/external_link_service.dart';
import 'package:asasfans_next/core/storage/storage_providers.dart';
import 'package:asasfans_next/features/content/application/content_providers.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/features/content/presentation/content_page.dart';
import 'package:asasfans_next/features/content/presentation/fanart_card.dart';
import 'package:asasfans_next/features/content/presentation/fanart_detail_page.dart';
import 'package:asasfans_next/features/creator/presentation/creator_link.dart';
import 'package:asasfans_next/features/handoff/presentation/anchor_restore.dart';
import 'package:asasfans_next/shared/widgets/app_controls.dart';
import 'package:asasfans_next/shared/widgets/app_page_bar.dart';
import 'package:asasfans_next/shared/widgets/glass/app_glass_navigation.dart';
import 'package:asasfans_next/shared/widgets/media_card_surface.dart';
import 'package:asasfans_next/shared/widgets/media_cover.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sqlite_fixture.dart';
import 'visual_fixture.dart';
import 'visual_harness.dart';

class _Links implements ExternalLinkService {
  final opened = <Uri>[];
  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}

/// Forty works: the fixture's eight types in turn, each with its own
/// identity, so the thirtieth is deep in a masonry of mixed heights.
List<FanartItem> _feed({int? without}) => [
  for (var i = 0; i < 40; i++)
    if (i != without)
      () {
        final base = fixtureFanart[i % fixtureFanart.length];
        final id = '95${i.toString().padLeft(4, '0')}';
        return FanartItem(
          identity: ContentIdentity(
            source: ContentSource.bilibiliDynamic,
            value: id,
          ),
          text: base.text.isEmpty ? '' : '${base.text}（$i）',
          authorName: base.authorName,
          authorUid: '3000$i',
          images: base.images,
          kind: base.kind,
          contentType: base.contentType,
          category: base.category,
          characterTags: base.characterTags,
          authorAvatarUrl: base.authorAvatarUrl,
          sourceUrl: Uri.https('t.bilibili.com', '/$id'),
        );
      }(),
];

/// The thirtieth work: a multi-image post, so it opens into its detail.
const _thirtieth = '950029';

/// After the layout change: the thirtieth work through detail, the original
/// post and back, a vanished target, a window crossing the breakpoint, its
/// maker and its more button, and the end of the feed above the dock. Each
/// check is on the part of the window nothing floats over, not on a widget
/// merely existing.
void main() {
  setUpAll(Visual.setUp);
  final phone = VisualView.phone.withSystemBars;

  Finder tileOf(String id) => find.byWidgetPredicate(
    (widget) => widget is FanartCard && widget.item.identity.value == id,
  );

  ScrollableState feed(WidgetTester tester) => tester
      .stateList<ScrollableState>(
        find.descendant(
          of: find.byType(ContentPage),
          matching: find.byType(Scrollable),
        ),
      )
      .firstWhere((state) => state.axisDirection == AxisDirection.down);

  /// The window less the status bar, a page bar still on screen and the
  /// floating navigation.
  Rect clearView(WidgetTester tester, VisualView view) {
    var top = view.safeArea.top;
    for (final bar in find.byType(AppPageBar).evaluate()) {
      final rect = tester.getRect(find.byWidget(bar.widget));
      if (rect.bottom > top && rect.top < view.size.height / 2) {
        top = rect.bottom;
      }
    }
    var bottom = view.size.height - view.safeArea.bottom;
    final dock = find.byType(AppGlassNavigation);
    if (dock.evaluate().isNotEmpty) bottom = tester.getRect(dock).top;
    return Rect.fromLTRB(0, top, view.size.width, bottom);
  }

  /// The tile's cover and byline are both in the clear part of the window.
  void expectClear(WidgetTester tester, VisualView view, String id) {
    final clear = clearView(tester, view);
    final cover = tester.getRect(
      find.descendant(of: tileOf(id), matching: find.byType(MediaCover)),
    );
    final more = tester.getRect(
      find.descendant(of: tileOf(id), matching: find.byType(MediaMoreButton)),
    );
    expect(cover.top, greaterThanOrEqualTo(clear.top - 1), reason: '$clear');
    expect(more.bottom, lessThanOrEqualTo(clear.bottom + 1), reason: '$clear');
  }

  Future<void> reveal(WidgetTester tester, String id) async {
    await tester.scrollUntilVisible(
      tileOf(id),
      240,
      scrollable: find
          .descendant(
            of: find.byType(ContentPage),
            matching: find.byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            ),
          )
          .first,
    );
    await tester.runAsync(
      () => Scrollable.ensureVisible(tester.element(tileOf(id)), alignment: .4),
    );
    await settleVisual(tester);
  }

  List<Override> app(_Links links, {List<FanartItem>? items, Override? db}) =>
      visualOverrides(
        extra: [
          externalLinkServiceProvider.overrideWithValue(links),
          fanartRepositoryProvider.overrideWithValue(
            FixtureFanart(items: items ?? _feed()),
          ),
          ?db,
        ],
      );

  /// Opens the thirtieth work into its detail and on to the original post;
  /// returns the list's offset when it left.
  Future<double> trip(WidgetTester tester, _Links links) async {
    await reveal(tester, _thirtieth);
    final offset = feed(tester).position.pixels;
    await tester.tap(
      find.descendant(
        of: tileOf(_thirtieth),
        matching: find.byType(MediaCover),
      ),
    );
    await settleVisual(tester);
    expect(find.byType(FanartDetailPage), findsOneWidget);
    await tester.tap(find.byTooltip('打开原动态'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await settleVisual(tester);
    expect(links.opened.last, Uri.https('t.bilibili.com', '/$_thirtieth'));
    return offset;
  }

  testVisual('the 30th work: detail, the post, back, and still in view', (
    tester,
  ) async {
    final links = _Links();
    await pumpVisualApp(
      tester,
      view: phone,
      location: '/content/fanart',
      overrides: app(links),
    );
    final before = await trip(tester, links);
    // Back from Bilibili to the detail, then back to the list.
    await tester.tap(find.byTooltip('返回').last);
    await settleVisual(tester);
    expect(find.byType(FanartDetailPage), findsNothing);
    expect(feed(tester).position.pixels, before);
    expectClear(tester, phone, _thirtieth);
    await shoot(tester, 'journey-30th-back', phone);
  });

  for (final (label, without) in [
    ('comes back to the 30th work', null),
    ('without the 30th work says so and lands close by', 29),
  ]) {
    testVisual('a cold return $label', (tester) async {
      final database = MemoryLocalDatabase();
      addTearDown(database.close);
      final db = localDatabaseProvider.overrideWithValue(database);
      final first = _Links();
      await pumpVisualApp(
        tester,
        view: phone,
        location: '/content/fanart',
        overrides: app(first, db: db),
      );
      await trip(tester, first);
      // Bilibili is in front and the process is reclaimed.
      await tester.pumpWidget(const SizedBox());

      final second = _Links();
      await pumpVisualApp(
        tester,
        view: phone,
        overrides: app(
          second,
          items: _feed(without: without),
          db: db,
        ),
      );
      // A notice lasts four seconds; watch for it while the return settles.
      const notice = '原位置已不在列表中，已回到相近位置';
      var noticed = find.text(notice).evaluate().isNotEmpty;
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        noticed |= find.text(notice).evaluate().isNotEmpty;
      }
      await settleVisual(tester);
      expect(second.opened, isEmpty);
      if (without == null) {
        expectClear(tester, phone, _thirtieth);
        await shoot(tester, 'journey-30th-cold', phone);
      } else {
        expect(tileOf(_thirtieth), findsNothing);
        expect(noticed, isTrue);
        // Close by: the works around it are on screen, not the top.
        expect(feed(tester).position.pixels, greaterThan(1000));
      }
    });
  }

  testVisual('a window crossing the breakpoint keeps the 30th work in view', (
    tester,
  ) async {
    final links = _Links();
    await pumpVisualApp(
      tester,
      view: phone,
      location: '/content/fanart',
      overrides: app(links),
    );
    await reveal(tester, _thirtieth);
    expectClear(tester, phone, _thirtieth);
    for (final view in [VisualView.wide, VisualView.tablet, phone]) {
      view.apply(tester);
      await settleVisual(tester);
      expect(tileOf(_thirtieth), findsOneWidget, reason: view.name);
      expectClear(tester, view, _thirtieth);
      await shoot(tester, 'journey-30th-resize', view);
    }
  });

  testVisual('the 30th work: its maker, its more button and itself', (
    tester,
  ) async {
    final links = _Links();
    await pumpVisualApp(
      tester,
      view: phone,
      location: '/content/fanart',
      overrides: app(links),
    );
    await reveal(tester, _thirtieth);
    final tile = tileOf(_thirtieth);
    await tester.tap(
      find
          .descendant(
            of: find.descendant(of: tile, matching: find.byType(CreatorLink)),
            matching: find.byType(InkWell),
          )
          .first,
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await settleVisual(tester);
    expect(links.opened.single, Uri.https('space.bilibili.com', '/300029'));
    expect(find.byType(FanartDetailPage), findsNothing);

    await tester.tap(
      find.descendant(of: tile, matching: find.byType(MediaMoreButton)),
    );
    await settleVisual(tester);
    expect(
      find.byWidgetPredicate((w) => w is AppSwitch && w.label == '稍后看'),
      findsOneWidget,
    );
    expect(links.opened, hasLength(1));
    expect(find.byType(FanartDetailPage), findsNothing);
  });

  testVisual('the last work ends above the dock and its buttons answer', (
    tester,
  ) async {
    final links = _Links();
    await pumpVisualApp(
      tester,
      view: phone,
      location: '/content/fanart',
      overrides: app(links),
    );
    for (var i = 0; i < 4; i++) {
      final position = feed(tester).position;
      position.jumpTo(position.maxScrollExtent);
      await settleVisual(tester, rounds: 3);
    }
    final last = _feed().last.identity.value;
    expectClear(tester, phone, last);
    await shoot(tester, 'journey-last-above-dock', phone);
    // Hit-tested, not only measured: the dock is not over it.
    await tester.tap(
      find.descendant(of: tileOf(last), matching: find.byType(MediaMoreButton)),
    );
    await settleVisual(tester);
    expect(
      find.byWidgetPredicate((w) => w is AppSwitch && w.label == '稍后看'),
      findsOneWidget,
    );
  });

  testVisual('keyboard focus in the feed is never under the dock', (
    tester,
  ) async {
    await pumpVisualApp(
      tester,
      view: phone,
      location: '/content/fanart',
      overrides: app(_Links()),
    );
    var inFeed = 0;
    for (var i = 0; i < 60; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final context = FocusManager.instance.primaryFocus?.context;
      if (context == null) continue;
      final scrollable = Scrollable.maybeOf(context, axis: Axis.vertical);
      if (scrollable == null || scrollable.widget.axis != Axis.vertical) {
        continue;
      }
      inFeed++;
      final box = context.findRenderObject()! as RenderBox;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      final clear = clearView(tester, phone);
      // A tall work shows its top; otherwise the whole of it is clear.
      expect(rect.top, greaterThanOrEqualTo(phone.safeArea.top - 1));
      if (rect.height <= clear.height) {
        expect(rect.bottom, lessThanOrEqualTo(clear.bottom + 1), reason: '$i');
      }
    }
    expect(inFeed, greaterThan(20));
  });

  testVisual('a notice sits above the dock, not over it', (tester) async {
    await pumpVisualApp(
      tester,
      view: phone,
      location: '/content/fanart',
      overrides: app(_Links()),
    );
    showAnchorFallbackNotice(tester.element(find.byType(FanartCard).first));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final dock = tester.getRect(find.byType(AppGlassNavigation));
    expect(
      tester.getRect(find.byType(SnackBar)).bottom,
      lessThanOrEqualTo(dock.top),
    );
  });
}
