import 'package:asasfans_next/app/providers.dart';
import 'package:asasfans_next/core/platform/external_link_service.dart';
import 'package:asasfans_next/features/tools/domain/community_tool.dart';
import 'package:asasfans_next/features/tools/presentation/tools_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Links implements ExternalLinkService {
  bool success = true;
  final opened = <Uri>[];
  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return success;
  }
}

Widget _host(_Links links, {double scale = 1}) => ProviderScope(
  overrides: [externalLinkServiceProvider.overrideWithValue(links)],
  child: MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showToolsSheet(context),
          child: const Text('打开工具'),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'each entry keeps its category, independent icon and original destination',
    (tester) async {
      tester.view
        ..physicalSize = const Size(1000, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final links = _Links();
      await tester.pumpWidget(_host(links));
      await tester.tap(find.text('打开工具'));
      await tester.pumpAndSettle();
      final icons = <IconData>{};
      for (final tool in communityTools) {
        await tester.enterText(find.byType(TextField), tool.name);
        await tester.pumpAndSettle();
        // The query is now also on screen inside the search field, so match the
        // label only where it is a tile's own Text, not editable content.
        final label = find.byWidgetPredicate(
          (widget) => widget is Text && widget.data == tool.name,
        );
        expect(label, findsOneWidget);
        final tile = find
            .ancestor(of: label, matching: find.byType(InkWell))
            .first;
        icons.add(
          tester
              .widget<Icon>(
                // The small external-link hint is not the tool's own glyph.
                find.descendant(
                  of: tile,
                  matching: find.byWidgetPredicate(
                    (widget) => widget is Icon && widget.size == 22,
                  ),
                ),
              )
              .icon!,
        );
        final category = switch (tool.category) {
          ToolCategory.content => '内容',
          ToolCategory.community => '社区',
          ToolCategory.utility => '实用工具',
        };
        expect(find.text(category), findsOneWidget);
        await tester.tap(label);
        await tester.pumpAndSettle();
        expect(links.opened.last, Uri.parse(tool.url));
      }
      expect(icons, hasLength(communityTools.length));
      expect(links.opened, hasLength(communityTools.length));
    },
  );

  testWidgets(
    'search is local, clears to the catalog and reports real open failures',
    (tester) async {
      final links = _Links()..success = false;
      await tester.pumpWidget(_host(links));
      await tester.tap(find.text('打开工具'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '不存在的工具');
      await tester.pumpAndSettle();
      expect(find.text('没有匹配的工具'), findsOneWidget);
      expect(links.opened, isEmpty);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(find.text('录音棚'), findsOneWidget);
      await tester.tap(find.text('录音棚'));
      await tester.pumpAndSettle();
      expect(find.text('无法打开链接'), findsOneWidget);
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      expect(find.byType(ToolsSheet), findsNothing);
    },
  );

  testWidgets('desktop drawer has a bounded width', (tester) async {
    tester.view
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(_Links()));
    await tester.tap(find.text('打开工具'));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(ToolsSheet)).width,
      lessThanOrEqualTo(720),
    );
  });

  testWidgets('narrow drawer supports large text and an open keyboard', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 568)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(_Links(), scale: 2));
    await tester.tap(find.text('打开工具'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.enterText(find.byType(TextField), '社区导航');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getBottomLeft(find.byType(TextField)).dy,
      lessThan(568 - 260),
    );
  });
}
