import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_failure.dart';
import '../domain/library_page.dart';

class LibraryListState<T> {
  const LibraryListState({
    this.items = const [],
    this.next,
    this.loading = true,
    this.ready = false,
    this.failure,
    this.epoch = 0,
  });
  final List<T> items;
  final LibraryCursor? next;
  final bool loading;
  final bool ready;
  final StorageFailure? failure;
  final int epoch;
  bool get canLoadMore => ready && !loading && failure == null && next != null;
}

/// Each read is bounded in SQL. A changed snapshot is never appended to the
/// previous revision. Notifications coalesce; a busy store eventually pauses
/// instead of creating an unbounded retry loop.
class LibraryPager<T> extends StateNotifier<LibraryListState<T>> {
  LibraryPager(this._load, Stream<int> changes) : super(LibraryListState<T>()) {
    _subscription = changes.listen((_) => _changed());
    unawaited(refresh());
  }
  final Future<LibraryPage<T>> Function(LibraryCursor?) _load;
  late final StreamSubscription<int> _subscription;
  int _generation = 0;
  bool _refreshQueued = false;
  int _automaticRestarts = 0;

  void _changed() {
    if (!mounted) return;
    if (state.loading) {
      _refreshQueued = true;
    } else {
      unawaited(refresh());
    }
  }

  Future<void> refresh() {
    if (!mounted) return Future.value();
    _automaticRestarts = 0;
    _refreshQueued = false;
    return _read(first: true);
  }

  Future<void> loadMore() =>
      !mounted || !state.canLoadMore ? Future.value() : _read(first: false);

  Future<void> retry() {
    if (!mounted || state.loading) return Future.value();
    return !state.ready || state.failure?.kind == StorageFailureKind.changed
        ? refresh()
        : _read(first: false);
  }

  Future<void> _read({required bool first}) async {
    final generation = ++_generation;
    final previous = state;
    state = LibraryListState(
      items: previous.items,
      next: first ? null : previous.next,
      ready: first ? false : previous.ready,
      epoch: previous.epoch + (first ? 1 : 0),
    );
    try {
      final page = await _load(first ? null : previous.next);
      if (!mounted || generation != _generation) return;
      if (!_refreshQueued) {
        state = LibraryListState(
          items: List.unmodifiable([
            if (!first) ...previous.items,
            ...page.items,
          ]),
          next: page.next,
          loading: false,
          ready: true,
          epoch: state.epoch,
        );
      }
    } catch (error) {
      if (!mounted || generation != _generation) return;
      state = LibraryListState(
        items: previous.items,
        next: first ? null : previous.next,
        ready: !first && previous.ready,
        loading: false,
        failure: error is StorageFailure
            ? error
            : const StorageFailure(StorageFailureKind.unavailable),
        epoch: state.epoch,
      );
    } finally {
      if (mounted && generation == _generation && _refreshQueued) {
        _refreshQueued = false;
        if (_automaticRestarts++ == 0) {
          await _read(first: true);
        } else {
          state = LibraryListState(
            items: previous.items,
            ready: previous.ready,
            loading: false,
            failure: const StorageFailure(StorageFailureKind.changed),
            epoch: state.epoch,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
