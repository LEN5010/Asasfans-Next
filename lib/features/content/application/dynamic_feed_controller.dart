import 'package:flutter/foundation.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/rate_limit_gate.dart';
import '../domain/dynamic_repository.dart';
import 'fanart_feed_controller.dart' show FeedStatus;
import 'feed_progress.dart';

@immutable
class DynamicFeedState {
  const DynamicFeedState({
    this.query = const DynamicQuery(),
    this.items = const [],
    this.status = FeedStatus.idle,
    this.nextCursor,
    this.total,
    this.failure,
  });

  final DynamicQuery query;
  final List<DynamicPost> items;
  final FeedStatus status;
  final String? nextCursor;
  final int? total;
  final ApiFailure? failure;

  bool get isEmptyResult => items.isEmpty && status == FeedStatus.endOfList;

  bool get canAppend =>
      nextCursor != null &&
      (status == FeedStatus.ready || status == FeedStatus.appendFailed);

  bool get isBusy =>
      status == FeedStatus.loadingFirstPage || status == FeedStatus.appending;

  DynamicFeedState copyWith({
    DynamicQuery? query,
    List<DynamicPost>? items,
    FeedStatus? status,
    ({String? value})? nextCursor,
    int? total,
    ApiFailure? failure,
    bool clearFailure = false,
  }) => DynamicFeedState(
    query: query ?? this.query,
    items: items ?? this.items,
    status: status ?? this.status,
    nextCursor: nextCursor == null ? this.nextCursor : nextCursor.value,
    total: total ?? this.total,
    failure: clearFailure ? null : (failure ?? this.failure),
  );
}

/// Drives the historical dynamics list.
///
/// Mirrors the fanart feed's generation handling so a late response for an
/// abandoned query cannot overwrite newer results. This source has no dataset
/// snapshot, so there is no 409 restart path here.
class DynamicFeedController extends ChangeNotifier {
  DynamicFeedController(this._repository, {DateTime Function()? clock})
    : _rateLimit = RateLimitGate(clock: clock);

  final DynamicRepository _repository;
  DynamicFeedState _state = const DynamicFeedState();
  int _generation = 0;
  bool _disposed = false;
  final RateLimitGate _rateLimit;
  final _progress = FeedProgress<DynamicPost>((item) => item.identity);
  int get generation => _generation;
  RequestCancellation? _inFlight;

  DynamicFeedState get state => _state;

  void _emit(DynamicFeedState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  Future<void> loadInitial() {
    if (_disposed || _state.status != FeedStatus.idle) return Future.value();
    _emit(_state.copyWith(status: FeedStatus.loadingFirstPage));
    return _loadFirstPage();
  }

  Future<void> applyQuery(DynamicQuery query) {
    if (_disposed) return Future.value();
    if (query == _state.query && _state.status != FeedStatus.idle) {
      return Future.value();
    }
    _emit(DynamicFeedState(query: query, status: FeedStatus.loadingFirstPage));
    return _loadFirstPage();
  }

  Future<void> refresh() {
    if (_disposed) return Future.value();
    _emit(
      _state.copyWith(status: FeedStatus.loadingFirstPage, clearFailure: true),
    );
    return _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    final generation = ++_generation;
    _progress.reset();
    _inFlight?.cancel();
    final cancellation = _inFlight = RequestCancellation();
    try {
      final page = await _rateLimit.run(
        () =>
            _repository.search(query: _state.query, cancellation: cancellation),
      );
      if (_disposed || generation != _generation) return;
      final progress = _progress.accept(
        page.items,
        continuation: page.nextCursor,
      );
      _emit(
        _state.copyWith(
          items: progress.added,
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

  Future<void> loadMore({bool automatic = false}) async {
    if (_state.status != FeedStatus.ready &&
        (automatic || _state.status != FeedStatus.appendFailed)) {
      return;
    }
    final cursor = _state.nextCursor;
    if (_disposed || cursor == null || _state.isBusy) return;
    final generation = _generation;
    _emit(_state.copyWith(status: FeedStatus.appending, clearFailure: true));
    try {
      final page = await _rateLimit.run(
        () => _repository.search(
          query: _state.query,
          cursor: cursor,
          cancellation: _inFlight = RequestCancellation(),
        ),
      );
      if (_disposed || generation != _generation) return;
      final progress = _progress.accept(
        page.items,
        continuation: page.nextCursor,
      );
      _emit(
        _state.copyWith(
          items: List.unmodifiable([..._state.items, ...progress.added]),
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
      _emit(_state.copyWith(status: FeedStatus.appendFailed, failure: failure));
    }
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
