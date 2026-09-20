import 'package:flutter/foundation.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/rate_limit_gate.dart';
import '../domain/fanart_repository.dart';
import 'feed_progress.dart';

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

  /// Continuation stopped making progress. A fresh run is required.
  stalled,
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

  bool get isEmptyResult => items.isEmpty && status == FeedStatus.endOfList;

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
    DateTime Function()? clock,
  }) : _state = FanartFeedState(query: query),
       _rateLimit = RateLimitGate(clock: clock);

  final FanartRepository _repository;
  FanartFeedState _state;
  int _generation = 0;
  bool _disposed = false;
  final RateLimitGate _rateLimit;
  final _progress = FeedProgress<FanartItem>((item) => item.identity);
  int get generation => _generation;
  RequestCancellation? _inFlight;

  FanartFeedState get state => _state;

  void _emit(FanartFeedState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  /// Replaces the query and reloads from the first page. Items from the old
  /// query are dropped immediately because they no longer match the filters.
  Future<void> applyQuery(FanartQuery query) {
    if (_disposed) return Future.value();
    if (query == _state.query && _state.status != FeedStatus.idle) {
      return Future.value();
    }
    _emit(FanartFeedState(query: query, status: FeedStatus.loadingFirstPage));
    return _loadFirstPage();
  }

  /// Reloads the first page while keeping current items on screen, so a
  /// refresh never flashes an empty list.
  Future<void> refresh() {
    if (_disposed) return Future.value();
    _emit(
      _state.copyWith(status: FeedStatus.loadingFirstPage, clearFailure: true),
    );
    return _loadFirstPage();
  }

  Future<void> loadInitial() {
    if (_disposed || _state.status != FeedStatus.idle) return Future.value();
    _emit(_state.copyWith(status: FeedStatus.loadingFirstPage));
    return _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    final generation = ++_generation;
    _progress.reset();
    _inFlight?.cancel();
    final cancellation = _inFlight = RequestCancellation();
    try {
      final page = await _rateLimit.run(
        () => _repository.page(query: _state.query, cancellation: cancellation),
      );
      if (_disposed || generation != _generation) return;
      final progress = _progress.accept(
        page.items,
        continuation: page.nextCursor,
      );
      _emit(
        _state.copyWith(
          items: progress.added,
          snapshotId: page.snapshotId,
          nextCursor: (value: progress.stalled ? null : page.nextCursor),
          total: page.total,
          failure: progress.stalled
              ? const ApiFailure(ApiFailureKind.paginationStalled)
              : null,
          status: progress.stalled
              ? FeedStatus.stalled
              : page.nextCursor == null
              ? FeedStatus.endOfList
              : FeedStatus.ready,
          clearFailure: !progress.stalled,
        ),
      );
    } on ApiFailure catch (failure) {
      if (_disposed ||
          generation != _generation ||
          failure.kind == ApiFailureKind.cancelled) {
        return;
      }
      _emit(_state.copyWith(status: FeedStatus.failed, failure: failure));
    }
  }

  /// Loads the page after the current cursor. Callers may fire this on scroll;
  /// duplicate calls while a request is in flight are ignored.
  Future<void> loadMore({bool automatic = false}) async {
    if (_state.status != FeedStatus.ready &&
        (automatic || _state.status != FeedStatus.appendFailed)) {
      return;
    }
    final cursor = _state.nextCursor;
    if (_disposed || cursor == null || _state.isBusy) return;
    final generation = _generation;
    _emit(_state.copyWith(status: FeedStatus.appending, clearFailure: true));
    final cancellation = _inFlight = RequestCancellation();
    try {
      final page = await _rateLimit.run(
        () => _repository.page(
          query: _state.query,
          cursor: cursor,
          cancellation: cancellation,
        ),
      );
      if (_disposed || generation != _generation) return;
      final progress = _progress.accept(
        page.items,
        continuation: page.nextCursor,
      );
      // A union page reports its *source's* snapshot, which legitimately
      // changes at the Bilibili/Douban boundary. The opaque cursor binds all
      // source revisions server-side; only a 409 invalidates this run.
      _emit(
        _state.copyWith(
          items: List.unmodifiable([..._state.items, ...progress.added]),
          snapshotId: page.snapshotId,
          nextCursor: (value: progress.stalled ? null : page.nextCursor),
          total: page.total,
          failure: progress.stalled
              ? const ApiFailure(ApiFailureKind.paginationStalled)
              : null,
          status: progress.stalled
              ? FeedStatus.stalled
              : page.nextCursor == null
              ? FeedStatus.endOfList
              : FeedStatus.ready,
        ),
      );
    } on ApiFailure catch (failure) {
      if (_disposed ||
          generation != _generation ||
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
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _inFlight?.cancel();
    super.dispose();
  }
}
