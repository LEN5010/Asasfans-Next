import 'package:asasfans_next/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'directions/direction_a.dart';
import 'directions/direction_b.dart';
import 'directions/direction_c.dart';
import 'visual_harness.dart';

/// U05: three structural directions for Today and 二创, from the same
/// fixture, screen and text size. Prototypes, not the app.
void main() {
  setUpAll(Visual.setUp);

  const screens = <String, Widget>{
    'dir-a_today': ATodayPage(),
    'dir-a_fanart': AFanartPage(),
    'dir-b_today': BTodayPage(),
    'dir-b_fanart': BFanartPage(),
    'dir-c_today': CTodayPage(),
    'dir-c_fanart': CFanartPage(),
  };

  for (final screen in screens.entries) {
    for (final view in [VisualView.phone, VisualView.phone.dark]) {
      testVisual('${screen.key} ${view.name}', (tester) async {
        view.apply(tester);
        await tester.pumpWidget(
          visualRoot(
            ProviderScope(
              overrides: visualOverrides(),
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light,
                darkTheme: AppTheme.dark,
                home: screen.value,
              ),
            ),
          ),
        );
        await settleVisual(tester);
        await shoot(
          tester,
          screen.key,
          view,
          provenance: 'prototype',
          measurements: {
            if (screen.key.endsWith('fanart'))
              'first_item_top': firstTop(
                tester,
                const {
                  'dir-a_fanart': 'AWork',
                  'dir-b_fanart': '_FanartRow',
                  'dir-c_fanart': '_Tile',
                }[screen.key]!,
              ),
          },
          notes: 'U05 direction study; not the current app',
        );
      });
    }
  }
}
