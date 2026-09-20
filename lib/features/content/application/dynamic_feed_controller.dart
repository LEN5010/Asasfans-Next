import 'package:flutter/foundation.dart';

import '../../../core/network/api_failure.dart';
import '../domain/dynamic_repository.dart';
import 'fanart_feed_controller.dart' show FeedStatus;

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

  bool get isEmptyResult =>
      items.isEmpty &&
      (status == FeedStatus.ready || status == FeedStatus.endOfList);

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
  DynamicFeedController(this._repository);

  final DynamicRepository _repository;
  DynamicFeedState _state = const DynamicFeedState();
  int _generation = 0;
  RequestCancellation? _inFlight;

  DynamicFeedState get state => _state;

  void _emit(DynamicFeedState next) {
    _state = next;
    notifyListeners();
  }

  Future<void> loadInitial() {
    if (_state.status != FeedStatus.idle) return Future.value();
    _emit(_state.copyWith(status: FeedStatus.loadingFirstPage));
    return _loadFirstPage();
  }

  Future<void> applyQuery(DynamicQuery query) {
    if (query == _state.query && _state.status != FeedStatus.idle) {
      return Future.value();
    }
    _emit(DynamicFeedState(query: query, status: FeedStatus.loadingFirstPage));
    return _loadFirstPage();
  }

  Future<void> refresh() {
    _emit(
      _state.copyWith(status: FeedStatus.loadingFirstPage, clearFailure: true),
    );
    return _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    final generation = ++_generation;
    _inFlight?.cancel();
    final cancellation = _inFlight = RequestCancellation();
    try {
      final page = await _repository.search(
        query: _state.query,
        cancellation: cancellation,
      );
      if (generation != _generation) return;
      _emit(
        _state.copyWith(
          items: page.items,
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

  Future<void> loadMore() async {
    final cursor = _state.nextCursor;
    if (cursor == null || _state.isBusy) return;
    final generation = _generation;
    _emit(_state.copyWith(status: FeedStatus.appending, clearFailure: true));
    try {
      final page = await _repository.search(
        query: _state.query,
        cursor: cursor,
        cancellation: RequestCancellation(),
      );
      if (generation != _generation) return;
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
      _emit(_state.copyWith(status: FeedStatus.appendFailed, failure: failure));
    }
  }

  @override
  void dispose() {
    _inFlight?.cancel();
    super.dispose();
  }
}
