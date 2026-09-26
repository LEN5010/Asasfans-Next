import 'package:asasfans_next/app/providers.dart';
import 'package:asasfans_next/core/platform/external_link_service.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/features/content/presentation/channel_tabs.dart';
import 'package:asasfans_next/features/content/presentation/fanart_detail_page.dart';
import 'package:asasfans_next/features/content/presentation/fanart_card.dart';
import 'package:asasfans_next/features/content/presentation/video_card.dart';
import 'package:asasfans_next/features/creator/presentation/creator_link.dart';
import 'package:asasfans_next/shared/widgets/media_card_surface.dart';
import 'package:asasfans_next/shared/widgets/media_cover.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_harness.dart';

class _Links implements ExternalLinkService {
  final opened = <Uri>[];
  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}

/// R05: targets, short labels and large text, checked in the real pages.
void main() {
  setUpAll(Visual.setUp);

  /// The creator link's own tap area inside [card], and the card's more
  /// button: the link is a full 48 dp band and the two never overlap.
  void expectCreatorBand(WidgetTester tester, Finder card) {
    final link = find.descendant(
      of: find.descendant(of: card, matching: find.byType(CreatorLink)),
      matching: find.byType(InkWell),
    );
    final more = find.descendant(
      of: card,
      matching: find.byType(MediaMoreButton),
    );
    final band = tester.getRect(link.first);
    expect(band.height, greaterThanOrEqualTo(48));
    expect(band.overlaps(tester.getRect(more.first)), isFalse);
    // And the work's own cover is not under it.
    final cover = tester.getRect(
      find.descendant(of: card, matching: find.byType(MediaCover)).first,
    );
    expect(band.overlaps(cover), isFalse);
  }

  testVisual('a work tile names its maker in one 48 dp target', (tester) async {
    await pumpVisualApp(
      tester,
      view: VisualView.phone,
      location: '/content/fanart',
    );
    expectCreatorBand(tester, find.byType(FanartCard).first);
    // The link is as wide as the name, not the line: the blank end of the
    // byline, just before the more button, still opens the work.
    final card = find.byType(FanartCard).first;
    final more = tester.getRect(
      find.descendant(of: card, matching: find.byType(MediaMoreButton)),
    );
    final link = tester.getRect(
      find
          .descendant(
            of: find.descendant(of: card, matching: find.byType(CreatorLink)),
            matching: find.byType(InkWell),
          )
          .first,
    );
    expect(link.right, lessThan(more.left - 8));
    await tester.tapAt(Offset(more.left - 4, more.center.dy));
    await settleVisual(tester);
    expect(find.byType(FanartDetailPage), findsOneWidget);
  });

  testVisual('the middle of a video work opens the work, not its maker', (
    tester,
  ) async {
    final links = _Links();
    await pumpVisualApp(
      tester,
      view: VisualView.phone,
      location: '/content/fanart',
      overrides: visualOverrides(
        extra: [externalLinkServiceProvider.overrideWithValue(links)],
      ),
    );
    final video = find.byWidgetPredicate(
      (widget) =>
          widget is FanartCard &&
          widget.item.contentType == FanartContentType.video,
    );
    await tester.scrollUntilVisible(
      video,
      200,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first,
    );
    await tester.ensureVisible(video);
    await settleVisual(tester);
    await tester.tap(video);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await settleVisual(tester);
    expect(links.opened.single.host, 't.bilibili.com');
  });

  testVisual('a video card names its maker in one 48 dp target', (
    tester,
  ) async {
    await pumpVisualApp(
      tester,
      view: VisualView.phone,
      location: '/content/videos',
    );
    expectCreatorBand(tester, find.byType(VideoCard).first);
    // A short date; the full one is what is read out.
    expect(find.textContaining('2026-'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('发布于 2026年9月26日')), findsWidgets);
  });

  testVisual('Today video lines keep room for the title', (tester) async {
    for (final view in [VisualView.phone, VisualView.narrow.scaled(2)]) {
      await pumpVisualApp(tester, view: view);
      final row = find.byType(VideoRow).first;
      // Built lazily: scroll until a line exists, then bring it into view.
      for (var i = 0; i < 20 && find.byType(VideoRow).evaluate().isEmpty; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.ensureVisible(row);
      await settleVisual(tester);
      final rowRect = tester.getRect(row);
      final cover = tester.getRect(
        find.descendant(of: row, matching: find.byType(MediaCover)),
      );
      final title = tester.getRect(
        find.descendant(
          of: row,
          matching: find.text(tester.widget<VideoRow>(row).video.title),
        ),
      );
      if (view == VisualView.phone) {
        // Side by side, with a real column for the words.
        expect(title.left, greaterThan(cover.right));
        expect(title.width, greaterThan(150));
      } else {
        // At 320 with 2x text the line stacks: the title gets the width.
        expect(title.top, greaterThan(cover.bottom));
        expect(title.width, greaterThan(rowRect.width * .8));
      }
      expectCreatorBand(tester, row);
      if (view != VisualView.phone) {
        await shoot(tester, 'today-video-stacked', view);
      }
      await tester.pumpWidget(const SizedBox());
    }
  });

  testVisual('我的 names every place in full at 320 with 2x text', (
    tester,
  ) async {
    final view = VisualView.narrow.scaled(2);
    await pumpVisualApp(tester, view: view, location: '/mine');
    for (final label in ['收藏', '稍后看', '历史记录', '继续观看', '时间书签', '应用内更新']) {
      final text = find.text(label);
      await tester.scrollUntilVisible(
        text,
        120,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      );
      final paragraph = tester.renderObject<RenderParagraph>(text.first);
      expect(paragraph.didExceedMaxLines, isFalse, reason: label);
    }
    // Settings are one tap from the title.
    expect(find.byTooltip('设置'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
    await settleVisual(tester);
    await shoot(tester, 'mine-library', view);
  });

  testVisual('the 设置 entry in the list still opens settings', (tester) async {
    await pumpVisualApp(tester, view: VisualView.phone, location: '/mine');
    final entry = find.text('设置');
    await tester.scrollUntilVisible(
      entry,
      160,
      scrollable: find.byType(Scrollable).first,
    );
    // Clear of the floating bar.
    await tester.runAsync(
      () => Scrollable.ensureVisible(tester.element(entry), alignment: .5),
    );
    await settleVisual(tester);
    await tester.tap(entry);
    await settleVisual(tester);
    expect(find.text('主题'), findsOneWidget);
  });

  testVisual('the selected channel reads as the page title', (tester) async {
    await pumpVisualApp(
      tester,
      view: VisualView.phone,
      location: '/content/fanart',
    );
    final handle = tester.ensureSemantics();
    final node = tester.getSemantics(
      find
          .descendant(
            of: find.byWidgetPredicate((widget) => widget is ChannelTabs),
            matching: find.text('二创'),
          )
          .first,
    );
    expect(node, isSemantics(isHeader: true, isSelected: true));
    handle.dispose();
  });

  testVisual('calendar controls fold to one row and open in place', (
    tester,
  ) async {
    for (final view in [VisualView.phone, VisualView.narrow.scaled(2)]) {
      await pumpVisualApp(tester, view: view, location: '/calendar');
      expect(find.text('贝拉'), findsNothing);
      final toggle = find.byTooltip('按类型或成员筛选');
      expect(tester.getSize(toggle).height, greaterThanOrEqualTo(48));
      await shoot(tester, 'calendar-folded', view);
      await tester.tap(toggle);
      await settleVisual(tester);
      await tester.tap(find.text('贝拉').first);
      await settleVisual(tester);
      // Folded again, the choice is named and removable on its own.
      await tester.tap(find.byTooltip('收起筛选'));
      await settleVisual(tester);
      expect(find.byTooltip('移除“贝拉”'), findsOneWidget);
      expect(find.text('筛选 1'), findsOneWidget);
      await tester.tap(find.byTooltip('移除“贝拉”'));
      await settleVisual(tester);
      expect(find.text('筛选 1'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testVisual('at 320 the week agenda is the large-target way through days', (
    tester,
  ) async {
    // Seven day cells cannot each be 48 dp in 320 px (they are 44, the
    // declared exception). Every day's events are instead reachable through
    // 周议程, whose switch and rows are full-size targets.
    const view = VisualView.narrow;
    await pumpVisualApp(tester, view: view, location: '/calendar');
    final week = find.text('周议程');
    expect(
      tester
          .getSize(
            find.ancestor(of: week, matching: find.byType(InkWell)).first,
          )
          .height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(week);
    await settleVisual(tester);
    // The whole fixture week (21–27 Sep) is listed, beyond the selected day.
    expect(find.textContaining('9 月 21 日 — 9 月 27 日'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('读信电台'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('读信电台'), findsWidgets);
    await shoot(tester, 'calendar-week-agenda', view);
  });

  test('compact dates stay short and exact', () {
    final now = DateTime.utc(2026, 9, 26, 4);
    expect(VideoCard.compactDate(DateTime.utc(2026, 9, 26, 1), now), '今天');
    // 23:30 in Shanghai on the 25th.
    expect(VideoCard.compactDate(DateTime.utc(2026, 9, 25, 15, 30), now), '昨天');
    expect(VideoCard.compactDate(DateTime.utc(2026, 9, 2, 4), now), '9-2');
    expect(
      VideoCard.compactDate(DateTime.utc(2025, 12, 31, 4), now),
      '2025-12-31',
    );
    expect(VideoCard.fullDate(DateTime.utc(2025, 12, 31, 20)), '2026年1月1日');
  });
}
