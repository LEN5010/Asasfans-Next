import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../../core/storage/local_database.dart';
import '../../library/data/cloud_collections.dart';
import '../../library/domain/library_repository.dart';
import '../domain/main_account.dart';
import 'main_account_controller.dart';

class CollectionSyncController extends ChangeNotifier {
  CollectionSyncController(this.account, this.db, this.library) {
    _subscription = library.collectionChanges.listen((_) => schedule());
  }
  final MainAccountController account;
  final LocalDatabase db;
  final LibraryRepository library;
  late final StreamSubscription<int> _subscription;
  Timer? _timer;
  bool busy = false;
  bool _closed = false;
  bool _again = false;
  String? error;
  DateTime? syncedAt;
  int unknownCount = 0;
  void _notify() {
    if (!_closed) notifyListeners();
  }

  void schedule({Duration delay = const Duration(seconds: 3)}) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      if (busy) {
        _again = true;
      } else {
        unawaited(sync());
      }
    });
  }

  Future<void> sync() async {
    final session = account.session;
    if (_closed || busy || session == null) return;
    bool active() => !_closed && account.session?.token == session.token;
    busy = true;
    error = null;
    _notify();
    final store = CloudCollections(db, session.user.id);
    try {
      await account.api.me(session.token);
      if (!active()) return;
      final pending = await store.pending(all: true);
      final unknown = <String>{};
      for (var offset = 0; offset < pending.length; offset += 200) {
        final batch = pending.sublist(
          offset,
          min(offset + 200, pending.length),
        );
        final missing = await account.api.push(session.token, [
          for (final row in batch) {'key': row['key'], 'op': row['op']},
        ]);
        if (!active()) return;
        await store.acknowledge(batch, missing);
        unknown.addAll(missing);
      }
      final remote = await account.api.favorites(session.token);
      if (!active()) return;
      await store.reconcile(remote);
      if (!active()) return;
      library.notifyCloudCommit();
      unknownCount = unknown.length;
      syncedAt = DateTime.now();
    } on MainAccountFailure catch (failure) {
      if (active()) {
        if (failure.expired) {
          await account.expire(session.token);
        } else {
          error = failure.message;
        }
      }
    } catch (_) {
      if (active()) error = '收藏同步失败，请重试';
    } finally {
      busy = false;
      _notify();
      if (_again && !_closed) {
        _again = false;
        schedule();
      }
    }
  }

  @override
  void dispose() {
    _closed = true;
    _timer?.cancel();
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
