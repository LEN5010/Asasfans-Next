import 'dart:async';

import 'package:asasfans_next/core/storage/storage_failure.dart';
import 'package:asasfans_next/features/library/application/library_pager.dart';
import 'package:asasfans_next/features/library/domain/library_page.dart';
import 'package:asasfans_next/features/library/presentation/library_paged_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'short personal pages autofill with a finite budget instead of waiting for a scroll',
    (tester) async {
      final changes = StreamController<int>.broadcast();
      var calls = 0;
      final pager = LibraryPager<int>((cursor) async {
        calls++;
        return LibraryPage(
          items: [calls],
          next: LibraryCursor(
            storeId: 's',
            revision: 1,
            query: 'q',
            key: [calls],
          ),
        );
      }, changes.stream);
      addTearDown(() async {
        pager.dispose();
        await changes.close();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: _View(pager: pager)),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 5); // Initial read + the shared four-page viewport budget.
      expect(pager.state.items, [1, 2, 3, 4, 5]);
      await tester.pump(const Duration(seconds: 1));
      expect(calls, 5);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'continuation failure leaves rows visible and automatic fills paused',
    (tester) async {
      final changes = StreamController<int>.broadcast();
      var calls = 0;
      final pager = LibraryPager<int>((cursor) async {
        calls++;
        if (calls == 2) {
          throw const StorageFailure(StorageFailureKind.unavailable);
        }
        return LibraryPage(
          items: [calls],
          next: cursor == null
              ? LibraryCursor(
                  storeId: 's',
                  revision: 1,
                  query: 'q',
                  key: [calls],
                )
              : null,
        );
      }, changes.stream);
      addTearDown(() async {
        pager.dispose();
        await changes.close();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: _View(pager: pager)),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('row 1'), findsOneWidget);
      expect(find.text('本地资料暂时无法读写，请重试'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(calls, 2);
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(calls, 3);
      expect(find.text('row 3'), findsOneWidget);
    },
  );
}

class _View extends StatefulWidget {
  const _View({required this.pager});
  final LibraryPager<int> pager;
  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  late final void Function() _stop;
  @override
  void initState() {
    super.initState();
    _stop = widget.pager.addListener((_) {
      if (mounted) setState(() {});
    }, fireImmediately: false);
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LibraryPagedList(
    state: widget.pager.state,
    pager: widget.pager,
    empty: '暂无内容',
    itemBuilder: (_, item) => Text('row $item'),
  );
}
