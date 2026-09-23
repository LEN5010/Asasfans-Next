import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/features/content/domain/saved_channel.dart';
import 'package:asasfans_next/features/content/presentation/saved_channel_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/library_fixture.dart';

void main() {
  testWidgets('save action and saved query share one compact menu', (
    tester,
  ) async {
    ChannelSpec? opened;
    await tester.pumpWidget(
      ProviderScope(
        overrides: offlineLibrary(),
        child: MaterialApp(
          home: Scaffold(
            body: SavedChannelBar(
              feed: ChannelFeed.fanart,
              currentSpec: () =>
                  ChannelSpec.ofFanart(const FanartQuery(keyword: '嘉然')),
              onOpen: (value) => opened = value,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('保存当前筛选'), findsNothing);
    await tester.tap(find.byTooltip('保存频道'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存当前筛选'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '我的频道');
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('保存频道'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的频道'));
    await tester.pumpAndSettle();
    expect(opened?.toFanart().keyword, '嘉然');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
