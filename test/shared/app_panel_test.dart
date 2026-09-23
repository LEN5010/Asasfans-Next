import 'package:asasfans_next/shared/widgets/app_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [390.0, 1200.0]) {
    testWidgets('root panel adapts at $width and returns a result', (
      tester,
    ) async {
      tester.view
        ..physicalSize = Size(width, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showAppPanel<String>(
                    context: context,
                    builder: (context) => Column(
                      children: [
                        const AppPanelHeader(title: '选择'),
                        Expanded(
                          child: ListView(
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, 'kept'),
                                child: const Text('确定'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), width >= 840 ? findsOneWidget : findsNothing);
      expect(
        find.byType(BottomSheet),
        width < 840 ? findsOneWidget : findsNothing,
      );
      expect(
        tester.getSize(find.byType(AppPanelHeader)).width,
        lessThanOrEqualTo(680),
      );
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(result, 'kept');
      expect(tester.takeException(), isNull);
    });
  }
}
