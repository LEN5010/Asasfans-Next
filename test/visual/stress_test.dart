import 'package:asasfans_next/shared/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_harness.dart';

/// U21: every page at the awkward sizes, large text included. A layout
/// error fails the test; with capture on, the 2.0 renders are kept for
/// review. Not a golden suite: the point is to find breakage.
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
    'settings': '/mine/settings',
    'updates': '/mine/updates',
    'rules': '/mine/rules',
  };
  const widths = {
    '320': Size(320, 640),
    '600': Size(600, 900),
    '840': Size(840, 1000),
  };

  for (final page in pages.entries) {
    for (final width in widths.entries) {
      for (final scale in [1.3, 2.0]) {
        final view = VisualView(
          'stress-${width.key}',
          width.value,
          pixelRatio: 1,
        ).scaled(scale);
        testVisual('${page.key} ${view.name}', (tester) async {
          await pumpVisualApp(tester, view: view, location: page.value);
          expect(tester.takeException(), isNull);
          if (scale == 2.0) await shoot(tester, page.key, view);
        });
      }
    }
  }

  testVisual('tools sheet at 320 and double text', (tester) async {
    const view = VisualView('stress-320', Size(320, 640), pixelRatio: 1);
    await pumpVisualApp(tester, view: view.scaled(2));
    await tester.tap(find.byIcon(AppIcons.tools));
    await settleVisual(tester);
    expect(tester.takeException(), isNull);
    await shoot(tester, 'tools', view.scaled(2));
  });
}
