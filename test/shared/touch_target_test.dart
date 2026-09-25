import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/features/content/presentation/fanart_filter_bar.dart';
import 'package:asasfans_next/shared/widgets/app_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets(
    'touch platforms hit controls at 48 dp around a 40 dp look',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          AppButton.icon(
            tooltip: '刷新',
            onPressed: () => taps++,
            icon: const Icon(Icons.refresh),
          ),
        ),
      );
      final hit = tester.getSize(find.byType(TextButton));
      expect(hit.width, greaterThanOrEqualTo(48));
      expect(hit.height, greaterThanOrEqualTo(48));
      // The visible surface stays compact.
      final visible = tester.getSize(
        find.descendant(
          of: find.byType(TextButton),
          matching: find.byType(Material),
        ),
      );
      expect(visible.height, 40);
      // A tap in the padding band, outside the visible surface, still counts.
      final center = tester.getCenter(find.byType(TextButton));
      await tester.tapAt(center + const Offset(0, 22));
      expect(taps, 1);

      await tester.pumpWidget(
        host(FanartQuickFilters(query: const FanartQuery(), onChanged: (_) {})),
      );
      final chip = find.text('全部成员');
      // The chip row: each chip's transparent band makes it 48 dp tall.
      final strip = tester.getSize(
        find.ancestor(of: chip, matching: find.byType(Row)).first,
      );
      expect(strip.height, greaterThanOrEqualTo(48));
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'pointer platforms keep compact geometry',
    (tester) async {
      tester.view
        ..physicalSize = const Size(1280, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        host(
          AppButton.icon(
            tooltip: '刷新',
            onPressed: () {},
            icon: const Icon(Icons.refresh),
          ),
        ),
      );
      expect(tester.getSize(find.byType(TextButton)).height, lessThan(48));
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.macOS,
      TargetPlatform.linux,
    }),
  );
}
