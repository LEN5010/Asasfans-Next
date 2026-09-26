import 'package:asasfans_next/features/content/application/content_providers.dart';
import 'package:asasfans_next/features/content/presentation/fanart_detail_page.dart';
import 'package:asasfans_next/features/calendar/application/calendar_providers.dart';
import 'package:asasfans_next/features/novels/presentation/novel_reader_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_fixture.dart';
import 'visual_harness.dart';

/// The pages as they are, rendered from the real widgets with the fixture.
/// Run through tool/visual_capture.sh to write PNGs; plain `flutter test`
/// only checks that every scene builds without an exception.
void main() {
  setUpAll(Visual.setUp);

  const pages = {
    'today': '/today',
    'videos': '/content/videos',
    'fanart': '/content/fanart',
    'dynamics': '/content/dynamics',
    'novels': '/content/novels',
    'calendar': '/calendar',
    'mine': '/mine',
  };
  const views = [VisualView.phone, VisualView.wide];
  // Where the first real content item starts: the content-space budget.
  const firstItem = {
    'videos': 'VideoCard',
    'fanart': 'FanartCard',
    'dynamics': 'DynamicCard',
    'novels': '_NovelCard',
  };

  for (final page in pages.entries) {
    for (final view in [...views, VisualView.phone.dark]) {
      testVisual('${page.key} ${view.name}', (tester) async {
        await pumpVisualApp(tester, view: view, location: page.value);
        final item = firstItem[page.key];
        await shoot(
          tester,
          page.key,
          view,
          measurements: {
            if (item != null) 'first_item_top': firstTop(tester, item),
          },
        );
      });
    }
  }

  for (final view in [VisualView.phone, VisualView.phone.dark]) {
    testVisual('fanart detail ${view.name}', (tester) async {
      await pumpVisualApp(tester, view: view, location: '/content/fanart');
      await pushVisual(
        tester,
        MaterialPageRoute(
          builder: (_) => FanartDetailPage(item: fixtureFanart.first),
        ),
      );
      await shoot(tester, 'fanart-detail', view);
    });

    testVisual('novel reader ${view.name}', (tester) async {
      await pumpVisualApp(tester, view: view, location: '/content/novels');
      await pushVisual(
        tester,
        MaterialPageRoute(
          builder: (_) => NovelReaderPage(item: fixtureNovels.first),
        ),
      );
      await shoot(tester, 'novel-reader', view);
    });
  }

  // Stress states: large text, the narrowest phone, failures and staleness.
  for (final (scenario, location) in [
    ('today', '/today'),
    ('fanart', '/content/fanart'),
    ('videos', '/content/videos'),
  ]) {
    for (final view in [VisualView.phone.scaled(2), VisualView.narrow]) {
      testVisual('$scenario ${view.name}', (tester) async {
        await pumpVisualApp(tester, view: view, location: location);
        await shoot(tester, scenario, view);
      });
    }
  }

  testVisual('fanart first-page failure', (tester) async {
    await pumpVisualApp(
      tester,
      view: VisualView.phone,
      location: '/content/fanart',
      overrides: visualOverrides(
        extra: [
          fanartRepositoryProvider.overrideWithValue(FixtureFanart(fail: true)),
        ],
      ),
    );
    await shoot(tester, 'fanart-failed', VisualView.phone);
  });

  testVisual('fanart no results', (tester) async {
    await pumpVisualApp(
      tester,
      view: VisualView.phone,
      location: '/content/fanart',
      overrides: visualOverrides(
        extra: [
          fanartRepositoryProvider.overrideWithValue(
            FixtureFanart(items: const []),
          ),
        ],
      ),
    );
    await shoot(tester, 'fanart-empty', VisualView.phone);
  });

  testVisual('today with a stale calendar and no fanart', (tester) async {
    await pumpVisualApp(
      tester,
      view: VisualView.phone,
      overrides: visualOverrides(
        extra: [
          calendarRepositoryProvider.overrideWithValue(
            FixtureCalendar(stale: true),
          ),
          fanartRepositoryProvider.overrideWithValue(
            FixtureFanart(items: const []),
          ),
        ],
      ),
    );
    await shoot(tester, 'today-stale', VisualView.phone);
  });

  testVisual('today with nothing scheduled', (tester) async {
    await pumpVisualApp(
      tester,
      view: VisualView.phone,
      overrides: visualOverrides(
        extra: [
          calendarRepositoryProvider.overrideWithValue(
            FixtureCalendar(list: const []),
          ),
        ],
      ),
    );
    await shoot(tester, 'today-no-events', VisualView.phone);
  });
}
