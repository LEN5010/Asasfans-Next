import 'dart:async';

import 'package:asasfans_next/core/storage/storage_failure.dart';
import 'package:asasfans_next/features/library/application/library_pager.dart';
import 'package:asasfans_next/features/library/domain/library_page.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> tick() => Future<void>.delayed(Duration.zero);
LibraryCursor cursor(int index) =>
    LibraryCursor(storeId: 'store', revision: 1, query: 'q', key: [index]);
void main() {
  test(
    'single-flight continuation, refresh generation and dispose ignore late completion',
    () async {
      final changes = StreamController<int>.broadcast(sync: true);
      final requests = <Completer<LibraryPage<int>>>[];
      final keys = <LibraryCursor?>[];
      final pager = LibraryPager<int>((key) {
        keys.add(key);
        final c = Completer<LibraryPage<int>>();
        requests.add(c);
        return c.future;
      }, changes.stream);
      requests[0].complete(LibraryPage(items: [1], next: cursor(1)));
      await tick();
      final more = pager.loadMore();
      await pager.loadMore();
      expect(requests, hasLength(2));
      final refreshed = pager.refresh();
      requests[2].complete(LibraryPage(items: [9]));
      await refreshed;
      requests[1].complete(LibraryPage(items: [2]));
      await more;
      expect(pager.state.items, [9]);
      final last = pager.refresh();
      pager.dispose();
      requests[3].complete(LibraryPage(items: [10]));
      await last;
      await changes.close();
      expect(keys[0], isNull);
      expect(keys[1], isNotNull);
    },
  );
  test(
    'continuation error pauses automatic retries, snapshot change requires first page',
    () async {
      final changes = StreamController<int>.broadcast();
      var calls = 0;
      final keys = <LibraryCursor?>[];
      final pager = LibraryPager<int>((key) async {
        keys.add(key);
        calls++;
        if (calls == 2) throw const StorageFailure(StorageFailureKind.changed);
        return LibraryPage(items: [calls], next: cursor(calls));
      }, changes.stream);
      addTearDown(() async {
        pager.dispose();
        await changes.close();
      });
      await tick();
      await pager.loadMore();
      expect(pager.state.items, [1]);
      expect(pager.state.canLoadMore, isFalse);
      await pager.loadMore();
      expect(calls, 2);
      await pager.retry();
      expect(keys.last, isNull);
      expect(pager.state.items, [3]);
    },
  );
  test(
    'continuous commit notifications coalesce and exhaust one automatic restart',
    () async {
      final changes = StreamController<int>.broadcast(sync: true);
      final requests = <Completer<LibraryPage<int>>>[];
      final pager = LibraryPager<int>((_) {
        final c = Completer<LibraryPage<int>>();
        requests.add(c);
        return c.future;
      }, changes.stream);
      addTearDown(() async {
        pager.dispose();
        await changes.close();
      });
      changes.add(1);
      changes.add(2);
      requests[0].complete(LibraryPage(items: [1]));
      await tick();
      expect(requests, hasLength(2));
      changes.add(3);
      requests[1].complete(LibraryPage(items: [2]));
      await tick();
      expect(requests, hasLength(2));
      expect(pager.state.failure?.kind, StorageFailureKind.changed);
      expect(pager.state.loading, isFalse);
      final retry = pager.retry();
      requests[2].complete(LibraryPage(items: [3]));
      await retry;
      expect(pager.state.items, [3]);
    },
  );
}
