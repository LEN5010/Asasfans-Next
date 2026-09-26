import 'package:asasfans_next/app/theme/app_theme.dart';
import 'package:asasfans_next/features/calendar/domain/calendar_event.dart';
import 'package:asasfans_next/features/calendar/presentation/calendar_event_widgets.dart';
import 'package:asasfans_next/features/content/presentation/channel_tabs.dart';
import 'package:asasfans_next/features/content/presentation/fanart_card.dart';
import 'package:asasfans_next/features/content/presentation/video_card.dart';
import 'package:asasfans_next/shared/widgets/app_controls.dart';
import 'package:asasfans_next/shared/widgets/glass/app_glass_navigation.dart';
import 'package:asasfans_next/shared/widgets/page_heading.dart';
import 'package:asasfans_next/shared/widgets/query_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_fixture.dart';
import 'visual_harness.dart';

/// U07: every shared piece of the direction-A system in one place, at three
/// text sizes, light and dark. Real widgets with the fixture.
void main() {
  setUpAll(Visual.setUp);

  Widget gallery() => Builder(
    builder: (context) {
      final day = DateTime.utc(2026, 9, 26);
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const RootHeading(title: '9月26日 星期六', subtitle: '今天，来枝江看看'),
          const SizedBox(height: 12),
          SectionHeading(title: '最新二创', action: '查看二创', onAction: () {}),
          ChannelTabs<int>(
            values: const [0, 1, 2, 3],
            labelOf: (value) => const ['视频', '二创', '动态', '小说'][value],
            selected: 1,
            onChanged: (_) {},
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppButton(onPressed: () {}, child: const Text('普通操作')),
              AppButton(
                selected: true,
                onPressed: () {},
                child: const Text('已选'),
              ),
              const AppButton(onPressed: null, child: Text('不可用')),
              AppButton.icon(
                tooltip: '筛选',
                filled: true,
                onPressed: () {},
                icon: const Badge(label: Text('2'), child: Icon(Icons.tune)),
              ),
              AppChoice(
                label: const Text('嘉然'),
                selected: true,
                onSelected: (_) {},
              ),
              AppChoice(
                label: const Text('贝拉'),
                selected: false,
                onSelected: (_) {},
              ),
            ],
          ),
          QuerySummary(
            padding: const EdgeInsets.only(top: 8),
            onClear: () {},
            status: '8 件',
            applied: [
              (label: '手书·动画', remove: () {}),
              (label: '最早', remove: () {}),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 12) / 2;
              final scaler = MediaQuery.textScalerOf(context);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  for (final item in [fixtureFanart[0], fixtureFanart[2]])
                    SizedBox(
                      width: width,
                      height: FanartCard.extentFor(item, width, scaler),
                      child: FanartCard(item: item, onTap: () {}),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 12) / 2;
              final scaler = MediaQuery.textScalerOf(context);
              return Row(
                spacing: 12,
                children: [
                  for (final video in fixtureVideos.take(2))
                    SizedBox(
                      width: width,
                      height: VideoCard.extentForWidth(width, scaler),
                      child: VideoCard(video: video),
                    ),
                ],
              );
            },
          ),
          VideoRow(video: fixtureVideos[3]),
          const SizedBox(height: 8),
          for (final event in [
            fixtureEvents[0],
            fixtureEvents[3],
            fixtureEvents[2].copyWith(status: EventStatus.tentative),
          ])
            CalendarAgendaRow(event: event, showDay: true, today: day),
          const SizedBox(height: 12),
          AppGlassNavigation(selected: 0, onSelect: (_) {}, onTools: () {}),
        ],
      );
    },
  );

  for (final base in [const VisualView('390', Size(390, 1900))]) {
    for (final view in [
      base,
      base.dark,
      base.scaled(1.3),
      base.scaled(2),
      base.dark.scaled(2),
    ]) {
      testVisual('components ${view.name}', (tester) async {
        view.apply(tester);
        await tester.pumpWidget(
          visualRoot(
            ProviderScope(
              overrides: visualOverrides(),
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light,
                darkTheme: AppTheme.dark,
                home: Scaffold(body: gallery()),
              ),
            ),
          ),
        );
        await settleVisual(tester);
        await shoot(tester, 'components', view);
      });
    }
  }
}
