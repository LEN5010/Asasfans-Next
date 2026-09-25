import 'package:asasfans_next/core/domain/content_identity.dart';
import 'package:asasfans_next/features/content/application/content_providers.dart';
import 'package:asasfans_next/features/content/domain/fanart_repository.dart';
import 'package:asasfans_next/features/content/presentation/content_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/library_fixture.dart';

FanartItem _item(String id) => FanartItem(
  identity: ContentIdentity(source: ContentSource.bilibiliDynamic, value: id),
  text: '作品 $id',
  authorName: '作者',
  authorUid: '1',
  images: const [],
  kind: FanartKind.fanart,
  contentType: FanartContentType.image,
  category: FanartCategory.normal,
  characterTags: const [],
);

class _Repository implements FanartRepository {
  @override
  Future<FanartPage> page({
    FanartQuery query = const FanartQuery(),
    String? cursor,
    RequestCancellation? cancellation,
  }) async => FanartPage(
    items: [for (var i = 0; i < 60; i++) _item('$i')],
    snapshotId: 's',
  );

  @override
  Future<FanartItem?> random({
    FanartQuery query = const FanartQuery(),
    RequestCancellation? cancellation,
  }) async => null;
}

/// What a screen reader gets for the control carrying [tooltip].
String spoken(WidgetTester tester, String tooltip) =>
    tester.getSemantics(find.byTooltip(tooltip)).getSemanticsData().tooltip;

void main() {
  // Buttons inside the search field used to get inverted, unreachable
  // semantics rects at some scroll offsets (e.g. 354 px in this layout) while
  // the field was partly scrolled out of the viewport.
  for (final keyword in ['', '生日']) {
    testWidgets('search controls keep valid semantics at every scroll offset'
        '${keyword.isEmpty ? '' : ' (with a query)'}', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...offlineLibrary(),
            fanartRepositoryProvider.overrideWithValue(_Repository()),
          ],
          child: const MaterialApp(home: ContentPage(channel: 'fanart')),
        ),
      );
      await tester.pumpAndSettle();
      if (keyword.isNotEmpty) {
        await tester.enterText(find.byType(TextField), keyword);
        await tester.pump();
        expect(spoken(tester, '清除搜索'), '清除搜索');
      }
      expect(spoken(tester, '筛选'), '筛选');
      final grid = find
          .descendant(
            of: find.byKey(const PageStorageKey('fanart-feed')),
            matching: find.byType(Scrollable),
          )
          .first;
      for (var offset = 300.0; offset <= 420; offset += 2) {
        tester.state<ScrollableState>(grid).position.jumpTo(offset);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'offset $offset');
      }
      semantics.dispose();
    });
  }
}
