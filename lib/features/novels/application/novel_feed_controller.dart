import 'package:flutter/foundation.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/rate_limit_gate.dart';
import '../../content/application/fanart_feed_controller.dart' show FeedStatus;
import '../../content/application/feed_progress.dart';
import '../domain/novel_repository.dart';

@immutable
class NovelFeedState {
  const NovelFeedState({
    this.query = const NovelQuery(),
    this.items = const [],
    this.status = FeedStatus.idle,
    this.nextOffset,
    this.total,
    this.failure,
  });

  final NovelQuery query;
  final List<NovelSummary> items;
  final FeedStatus status;
  final int? nextOffset;
  final int? total;
  final ApiFailure? failure;

  bool get isEmptyResult => items.isEmpty && status == FeedStatus.endOfList;

  bool get isBusy =>
      status == FeedStatus.loadingFirstPage || status == FeedStatus.appending;

  NovelFeedState copyWith({
    NovelQuery? query,
    List<NovelSummary>? items,
    FeedStatus? status,
    ({int? value})? nextOffset,
    int? total,
    ApiFailure? failure,
    bool clearFailure = false,
  }) => NovelFeedState(
    query: query ?? this.query,
    items: items ?? this.items,
    status: status ?? this.status,
    nextOffset: nextOffset == null ? this.nextOffset : nextOffset.value,
    total: total ?? this.total,
    failure: clearFailure ? null : (failure ?? this.failure),
  );
}

/// Drives the novel list with the same generation handling as the other
/// archive feeds. The archive pages by offset; the next offset stands in for
/// the continuation cursor, so a page that makes no progress stalls the run.
class NovelFeedController extends ChangeNotifier {
  NovelFeedController(this._repository, {DateTime Function()? clock})
    : _rateLimit = RateLimitGate(clock: clock);

  final NovelRepository _repository;
  NovelFeedState _state = const NovelFeedState();
  int _generation = 0;
  bool _disposed = false;
  final RateLimitGate _rateLimit;
  final _progress = FeedProgress<NovelSummary>((item) => item.identity);
  int get generation => _generation;
  RequestCancellation? _inFlight;

  NovelFeedState get state => _state;

  void _emit(NovelFeedState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  Future<void> loadInitial() {
    if (_disposed || _state.status != FeedStatus.idle) return Future.value();
    _emit(_state.copyWith(status: FeedStatus.loadingFirstPage));
    return _loadFirstPage();
  }

  Future<void> applyQuery(NovelQuery query) {
    if (_disposed) return Future.value();
    if (query == _state.query && _state.status != FeedStatus.idle) {
      return Future.value();
    }
    _emit(NovelFeedState(query: query, status: FeedStatus.loadingFirstPage));
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
        continuation: page.nextOffset,
      );
      _emit(
        _state.copyWith(
          items: progress.added,
          nextOffset: (value: progress.stalled ? null : page.nextOffset),
          total: page.total,
          failure: progress.stalled
              ? const ApiFailure(ApiFailureKind.paginationStalled)
              : null,
          status: progress.stalled
              ? FeedStatus.stalled
              : page.nextOffset == null
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
    final offset = _state.nextOffset;
    if (_disposed || offset == null || _state.isBusy) return;
    final generation = _generation;
    _emit(_state.copyWith(status: FeedStatus.appending, clearFailure: true));
    final cancellation = _inFlight = RequestCancellation();
    try {
      final page = await _rateLimit.run(
        () => _repository.search(
          query: _state.query,
          offset: offset,
          cancellation: cancellation,
        ),
      );
      if (_disposed || generation != _generation) return;
      final progress = _progress.accept(
        page.items,
        continuation: page.nextOffset,
      );
      _emit(
        _state.copyWith(
          items: List.unmodifiable([..._state.items, ...progress.added]),
          nextOffset: (value: progress.stalled ? null : page.nextOffset),
          total: page.total,
          failure: progress.stalled
              ? const ApiFailure(ApiFailureKind.paginationStalled)
              : null,
          status: progress.stalled
              ? FeedStatus.stalled
              : page.nextOffset == null
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
