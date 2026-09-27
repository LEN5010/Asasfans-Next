import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/features/calendar/application/calendar_providers.dart';
import 'package:asasfans_next/features/calendar/domain/calendar_event.dart';
import 'package:asasfans_next/features/content/application/content_providers.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/features/content/presentation/fanart_card.dart';
import 'package:asasfans_next/features/creator/presentation/creator_link.dart';
import 'package:asasfans_next/features/preferences/domain/app_preferences.dart';
import 'package:asasfans_next/shared/widgets/media_card_surface.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_fixture.dart';
import 'visual_harness.dart';

/// The two pages the layout checkpoint changes, Today and 二创, on one set
/// of mixed works: two short-titled videos, a portrait, a landscape, a text
/// work, a long strip, a set and a long title. Narrow and wide, light and
/// dark, the schedule at 0, 1 and several events, every module off, large
/// text, and a tile at rest, under the pointer and under keyboard focus.
///
/// Only public app behaviour is used, so the same file renders the baseline
/// commit for the before images. Measurements go to the manifest.
FanartItem _work(
  String id,
  String text, {
  List<String> images = const [],
  FanartContentType type = FanartContentType.image,
  String author = '枝江画手',
}) => FanartItem(
  identity: ContentIdentity(source: ContentSource.bilibiliDynamic, value: id),
  text: text,
  authorName: author,
  authorUid: '4${id.hashCode.abs() % 100000}',
  images: [for (final name in images) art(name)],
  kind: FanartKind.fanart,
  contentType: type,
  category: type == FanartContentType.video
      ? FanartCategory.handwriting
      : FanartCategory.normal,
  characterTags: const [FanartCharacter.diana],
  authorAvatarUrl: art('avatar-2'),
  sourceUrl: Uri.https('t.bilibili.com', '/$id'),
);

final reviewWorks = <FanartItem>[
  _work(
    '960001',
    '手书《晚安》',
    images: ['land-c'],
    type: FanartContentType.video,
    author: '手书工作室',
  ),
  _work('960002', '竖版插画：秋日围巾', images: ['port-a'], author: '小枝的调色盘'),
  _work(
    '960003',
    '一篇很短的小故事：那天晚上，直播间的弹幕像雨一样落下来，她说今天也要好好吃饭哦。我把这句话抄在了便签上。',
    type: FanartContentType.text,
    author: '晚安故事会',
  ),
  _work('960004', '横版：练舞后的休息时间', images: ['land-b'], author: '拉姐的舞鞋'),
  _work(
    '960005',
    '剪辑《夏日》',
    images: ['cover-3'],
    type: FanartContentType.video,
    author: '剪辑组',
  ),
  _work('960006', '长图条漫：从早到晚的一天', images: ['tall-a'], author: '条漫练习生'),
  _work(
    '960007',
    '表情包合集',
    images: ['square-a', 'square-b', 'port-b', 'land-d'],
    author: '表情包仓库',
  ),
  _work(
    '960008',
    '这是一个特别特别长的标题，用来检查两行截断之后作者名是否还紧跟在标题下面，而不是被推到很远的地方',
    images: ['wide-a'],
    author: '名字也很长的一位二创作者（测试用）',
  ),
];

List<CalendarEvent> _events(int count) => [
  for (var i = 0; i < count; i++)
    CalendarEvent(
      uid: 'review-$i',
      title: ['嘉然 · 周六晚间杂谈', '贝拉 · 舞蹈直播', '乃琳 · 读信电台', '心宜 · 新曲首唱'][i % 4],
      start: DateTime.utc(2026, 9, 26, 10 + i * 2),
      end: DateTime.utc(2026, 9, 26, 11 + i * 2),
      allDay: false,
      members: [
        ['嘉然'],
        ['贝拉'],
        ['乃琳'],
        ['心宜'],
      ][i % 4],
      categories: const ['直播'],
    ),
];

void main() {
  setUpAll(Visual.setUp);

  List<Override> overrides({
    int events = 2,
    AppPreferences preferences = const AppPreferences(),
  }) => visualOverrides(
    preferences: preferences,
    extra: [
      fanartRepositoryProvider.overrideWithValue(
        FixtureFanart(items: reviewWorks),
      ),
      calendarRepositoryProvider.overrideWithValue(
        FixtureCalendar(list: _events(events)),
      ),
    ],
  );

  /// Tile geometry the review asks about: each tile's height, and for the
  /// videos, the space between the last line of the title and the byline.
  Map<String, Object?> measure(WidgetTester tester) {
    final out = <String, Object?>{};
    for (final element in find.byType(FanartCard).evaluate()) {
      final card = element.widget as FanartCard;
      final tile = find.byWidget(card);
      final rect = tester.getRect(tile);
      final entry = <String, Object?>{
        'type': card.item.contentType.name,
        'rect': [rect.left, rect.top, rect.width, rect.height],
      };
      final title = find.descendant(
        of: tile,
        matching: find.text(card.item.text),
      );
      final more = find.descendant(
        of: tile,
        matching: find.byType(MediaMoreButton),
      );
      if (title.evaluate().isNotEmpty && more.evaluate().isNotEmpty) {
        final band = find
            .ancestor(of: more, matching: find.byType(SizedBox))
            .first;
        entry['title_to_byline'] =
            tester.getRect(band).top - tester.getRect(title).bottom;
      }
      out[card.item.identity.value] = entry;
    }
    return out;
  }

  Future<void> page(
    WidgetTester tester,
    String name,
    String location,
    VisualView view, {
    int events = 2,
    AppPreferences preferences = const AppPreferences(),
  }) async {
    await pumpVisualApp(
      tester,
      view: view,
      location: location,
      overrides: overrides(events: events, preferences: preferences),
    );
    expect(tester.takeException(), isNull);
    await shoot(tester, name, view, measurements: {'tiles': measure(tester)});
  }

  final views = [
    VisualView.phone,
    VisualView.phone.dark,
    VisualView.tablet,
    VisualView.wide,
    VisualView.wide.dark,
  ];
  for (final view in views) {
    testVisual('today ${view.name}', (tester) async {
      await page(tester, 'review-today', '/today', view);
    });
    testVisual('fanart ${view.name}', (tester) async {
      await page(tester, 'review-fanart', '/content/fanart', view);
    });
  }

  for (final view in [VisualView.phone, VisualView.wide]) {
    for (final count in [0, 1, 4]) {
      testVisual('today with $count events ${view.name}', (tester) async {
        await page(
          tester,
          'review-today-events$count',
          '/today',
          view,
          events: count,
        );
      });
    }
    testVisual('today with every module off ${view.name}', (tester) async {
      await page(
        tester,
        'review-today-off',
        '/today',
        view,
        preferences: const AppPreferences(
          hiddenHomeSections: {...HomeSection.values},
        ),
      );
    });
  }

  for (final view in [
    VisualView.narrow.scaled(2),
    VisualView.phone.scaled(1.6),
  ]) {
    testVisual('large text ${view.name}', (tester) async {
      await page(tester, 'review-fanart', '/content/fanart', view);
      await page(tester, 'review-today', '/today', view);
    });
  }

  // At rest, under the pointer, under keyboard focus; the pointer also over
  // a maker's name, where the name alone should answer.
  for (final view in [VisualView.wide, VisualView.wide.dark]) {
    testVisual('fanart states ${view.name}', (tester) async {
      await pumpVisualApp(
        tester,
        view: view,
        location: '/content/fanart',
        overrides: overrides(),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(1, 1));
      addTearDown(mouse.removePointer);
      await tester.pump();
      await shoot(tester, 'review-state-idle', view);

      final video = find.byWidgetPredicate(
        (w) => w is FanartCard && w.item.identity.value == '960001',
      );
      final text = find.byWidgetPredicate(
        (w) => w is FanartCard && w.item.identity.value == '960003',
      );
      await mouse.moveTo(tester.getCenter(video));
      await settleVisual(tester, rounds: 2);
      await shoot(tester, 'review-state-hover-tile', view);
      await mouse.moveTo(
        tester.getCenter(
          find.descendant(of: text, matching: find.byType(CreatorLink)).first,
        ),
      );
      await settleVisual(tester, rounds: 2);
      await shoot(tester, 'review-state-hover-maker', view);

      await mouse.moveTo(const Offset(1, 1));
      for (var i = 0; i < 40; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        var inTile = false;
        FocusManager.instance.primaryFocus?.context?.visitAncestorElements((e) {
          inTile = e.widget is FanartCard;
          return !inTile;
        });
        if (inTile) break;
      }
      await settleVisual(tester, rounds: 2);
      await shoot(tester, 'review-state-focus', view);
      expect(tester.takeException(), isNull);
    });
  }
}
