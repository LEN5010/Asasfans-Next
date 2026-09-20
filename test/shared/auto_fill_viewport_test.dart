import 'package:asasfans_next/shared/widgets/auto_fill_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Feed extends StatefulWidget {
  const _Feed({super.key});
  @override
  State<_Feed> createState() => _FeedState();
}

class _FeedState extends State<_Feed> {
  final scroll = ScrollController();
  int requests = 0;
  int generation = 0;
  bool loading = false;
  bool failed = false;
  bool empty = false;
  bool failNext = false;

  Future<void> more() async {
    if (loading || failed) return;
    setState(() {
      loading = true;
      requests++;
    });
    await Future<void>.value();
    if (mounted) {
      setState(() {
        loading = false;
        failed = failNext;
      });
    }
  }

  void newQuery({bool returnEmpty = false, bool fail = false}) => setState(() {
    empty = returnEmpty;
    failNext = fail;
    generation++;
  });

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AutoFillViewport(
    controller: scroll,
    resetKey: generation,
    canLoadMore: !loading && !failed,
    onLoadMore: more,
    child: ListView.builder(
      controller: scroll,
      itemCount: empty ? 0 : requests + 1,
      itemExtent: 25,
      itemBuilder: (_, index) => Text('item $index'),
    ),
  );
}

void main() {
  testWidgets(
    'short pages fill automatically, stop on budget, and can continue explicitly',
    (tester) async {
      final key = GlobalKey<_FeedState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: _Feed(key: key)),
        ),
      );
      await tester.pumpAndSettle();
      expect(key.currentState!.requests, 4);
      expect(find.text('继续加载'), findsOneWidget);
      await tester.tap(find.text('继续加载'));
      await tester.pumpAndSettle();
      expect(key.currentState!.requests, 8);
    },
  );

  testWidgets('resize and a fresh query renew the finite budget', (
    tester,
  ) async {
    final key = GlobalKey<_FeedState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: _Feed(key: key)),
      ),
    );
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(900, 800);
    addTearDown(tester.view.reset);
    await tester.pumpAndSettle();
    expect(key.currentState!.requests, 8);
    key.currentState!.newQuery();
    await tester.pumpAndSettle();
    expect(key.currentState!.requests, 12);
  });

  testWidgets(
    'an empty scrollable also fills, but failure suppresses all retries',
    (tester) async {
      final key = GlobalKey<_FeedState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: _Feed(key: key)),
        ),
      );
      await tester.pumpAndSettle();
      key.currentState!.newQuery(returnEmpty: true, fail: true);
      await tester.pumpAndSettle();
      expect(key.currentState!.requests, 5);
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(key.currentState!.requests, 5);
    },
  );
}
