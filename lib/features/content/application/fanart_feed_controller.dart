import 'package:flutter/foundation.dart';

import '../../../core/network/api_failure.dart';
import '../domain/fanart_repository.dart';

enum FeedStatus {
  /// No request has been issued for the current query yet.
  idle,

  /// First page in flight; existing items stay visible until it resolves.
  loadingFirstPage,

  /// A page is available and a following page may still exist.
  ready,

  /// The server returned no cursor: the list is complete.
  endOfList,

  /// An append is in flight for the current generation.
  appending,

  /// The first page failed; the list has nothing to show.
  failed,

  /// An append failed; earlier items remain valid and retry is offered.
  appendFailed,
}

@immutable
class FanartFeedState {
  const FanartFeedState({
    this.query = const FanartQuery(),
    this.items = const [],
    this.status = FeedStatus.idle,
    this.snapshotId,
    this.nextCursor,
    this.total,
    this.failure,
  });

  final FanartQuery query;
  final List<FanartItem> items;
  final FeedStatus status;
  final String? snapshotId;
  final String? nextCursor;
  final int? total;
  final ApiFailure? failure;

  bool get isEmptyResult =>
      items.isEmpty &&
      (status == FeedStatus.ready || status == FeedStatus.endOfList);

  bool get canAppend =>
      nextCursor != null &&
      (status == FeedStatus.ready || status == FeedStatus.appendFailed);

  bool get isBusy =>
      status == FeedStatus.loadingFirstPage || status == FeedStatus.appending;

  /// `nextCursor` is passed as a one-element wrapper so that "keep the current
  /// cursor" and "the server returned no cursor" stay distinguishable.
  FanartFeedState copyWith({
    FanartQuery? query,
    List<FanartItem>? items,
    FeedStatus? status,
    String? snapshotId,
    ({String? value})? nextCursor,
    int? total,
    ApiFailure? failure,
    bool clearFailure = false,
  }) => FanartFeedState(
    query: query ?? this.query,
    items: items ?? this.items,
    status: status ?? this.status,
    snapshotId: snapshotId ?? this.snapshotId,
    nextCursor: nextCursor == null ? this.nextCursor : nextCursor.value,
    total: total ?? this.total,
    failure: clearFailure ? null : (failure ?? this.failure),
  );
}

/// Drives one fanart list.
///
/// Every request carries a generation. Changing the query or refreshing bumps
/// it, so a slow response for an abandoned query can never overwrite newer
/// results. At most one append is in flight per generation.
class FanartFeedController extends ChangeNotifier {
  FanartFeedController(
    this._repository, {
    FanartQuery query = const FanartQuery(),
  }) : _state = FanartFeedState(query: query);

  final FanartRepository _repository;
  FanartFeedState _state;
  int _generation = 0;
  RequestCancellation? _inFlight;

  FanartFeedState get state => _state;

  void _emit(FanartFeedState next) {
    _state = next;
    notifyListeners();
  }

  /// Replaces the query and reloads from the first page. Items from the old
  /// query are dropped immediately because they no longer match the filters.
  Future<void> applyQuery(FanartQuery query) {
    if (query == _state.query && _state.status != FeedStatus.idle) {
      return Future.value();
    }
    _emit(FanartFeedState(query: query, status: FeedStatus.loadingFirstPage));
    return _loadFirstPage();
  }

  /// Reloads the first page while keeping current items on screen, so a
  /// refresh never flashes an empty list.
  Future<void> refresh() {
    _emit(
      _state.copyWith(status: FeedStatus.loadingFirstPage, clearFailure: true),
    );
    return _loadFirstPage();
  }

  Future<void> loadInitial() {
    if (_state.status != FeedStatus.idle) return Future.value();
    _emit(_state.copyWith(status: FeedStatus.loadingFirstPage));
    return _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    final generation = ++_generation;
    _inFlight?.cancel();
    final cancellation = _inFlight = RequestCancellation();
    try {
      final page = await _repository.page(
        query: _state.query,
        cancellation: cancellation,
      );
      if (generation != _generation) return;
      _emit(
        _state.copyWith(
          items: page.items,
          snapshotId: page.snapshotId,
          nextCursor: (value: page.nextCursor),
          total: page.total,
          status: page.nextCursor == null
              ? FeedStatus.endOfList
              : FeedStatus.ready,
          clearFailure: true,
        ),
      );
    } on ApiFailure catch (failure) {
      if (generation != _generation ||
          failure.kind == ApiFailureKind.cancelled) {
        return;
      }
      _emit(_state.copyWith(status: FeedStatus.failed, failure: failure));
    }
  }

  /// Loads the page after the current cursor. Callers may fire this on scroll;
  /// duplicate calls while a request is in flight are ignored.
  Future<void> loadMore() async {
    final cursor = _state.nextCursor;
    if (cursor == null || _state.isBusy) return;
    final generation = _generation;
    _emit(_state.copyWith(status: FeedStatus.appending, clearFailure: true));
    final cancellation = RequestCancellation();
    try {
      final page = await _repository.page(
        query: _state.query,
        cursor: cursor,
        cancellation: cancellation,
      );
      if (generation != _generation) return;
      // A cursor is only valid inside the dataset version that issued it.
      if (_state.snapshotId != null && page.snapshotId != _state.snapshotId) {
        await _restartAfterDatasetChange();
        return;
      }
      _emit(
        _state.copyWith(
          items: [..._state.items, ...page.items],
          nextCursor: (value: page.nextCursor),
          total: page.total,
          status: page.nextCursor == null
              ? FeedStatus.endOfList
              : FeedStatus.ready,
        ),
      );
    } on ApiFailure catch (failure) {
      if (generation != _generation ||
          failure.kind == ApiFailureKind.cancelled) {
        return;
      }
      if (failure.kind == ApiFailureKind.datasetChanged) {
        await _restartAfterDatasetChange();
        return;
      }
      _emit(_state.copyWith(status: FeedStatus.appendFailed, failure: failure));
    }
  }

  /// A 409 ends the current run. The stale cursor is dropped and the first page
  /// is requested again; existing items stay until the new first page arrives,
  /// and the response is never appended to a list built from the old dataset.
  Future<void> _restartAfterDatasetChange() {
    _emit(
      _state.copyWith(
        status: FeedStatus.loadingFirstPage,
        nextCursor: (value: null),
        clearFailure: true,
      ),
    );
    return _loadFirstPage();
  }

  @override
  void dispose() {
    _inFlight?.cancel();
    super.dispose();
  }
}
