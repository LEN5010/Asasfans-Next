import 'package:flutter/foundation.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/rate_limit_gate.dart';
import '../domain/community_video_repository.dart';
import 'community_video_pager.dart';
import 'fanart_feed_controller.dart' show FeedStatus;
import 'feed_progress.dart';

@immutable
class CommunityFeedState {
  const CommunityFeedState({
    this.query = const CommunityVideoQuery(),
    this.videos = const [],
    this.status = FeedStatus.idle,
    this.page = 0,
    this.total,
    this.failure,
  });

  final CommunityVideoQuery query;
  final List<CommunityVideo> videos;
  final FeedStatus status;

  /// Last page successfully loaded; 0 means nothing yet.
  final int page;
  final int? total;
  final ApiFailure? failure;

  bool get isEmptyResult => videos.isEmpty && status == FeedStatus.endOfList;

  bool get isBusy =>
      status == FeedStatus.loadingFirstPage || status == FeedStatus.appending;

  CommunityFeedState copyWith({
    CommunityVideoQuery? query,
    List<CommunityVideo>? videos,
    FeedStatus? status,
    int? page,
    int? total,
    ApiFailure? failure,
    bool clearFailure = false,
  }) => CommunityFeedState(
    query: query ?? this.query,
    videos: videos ?? this.videos,
    status: status ?? this.status,
    page: page ?? this.page,
    total: total ?? this.total,
    failure: clearFailure ? null : (failure ?? this.failure),
  );
}

/// Drives the clips list.
///
/// This source pages by number rather than by cursor, so the controller tracks
/// the last page it accepted and drops responses from an abandoned query using
/// the same generation rule as the other feeds.
class CommunityFeedController extends ChangeNotifier {
  CommunityFeedController(
    this._repository, {
    CommunityVideoQuery query = const CommunityVideoQuery(),
    List<String> anyTags = const [],
    DateTime Function()? clock,
  }) : _state = CommunityFeedState(query: query),
       _anyTags = List.unmodifiable(anyTags),
       _clock = clock ?? DateTime.now,
       _rateLimit = RateLimitGate(clock: clock);

  final CommunityVideoRepository _repository;
  final List<String> _anyTags;
  final DateTime Function() _clock;
  CommunityVideoPager? _pager;
  CommunityFeedState _state;
  int _generation = 0;
  bool _disposed = false;
  final RateLimitGate _rateLimit;
  final _progress = FeedProgress<CommunityVideo>((item) => item.identity);
  int get generation => _generation;
  RequestCancellation? _inFlight;

  CommunityFeedState get state => _state;

  void _emit(CommunityFeedState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  Future<void> loadInitial() {
    if (_disposed || _state.status != FeedStatus.idle) return Future.value();
    _emit(_state.copyWith(status: FeedStatus.loadingFirstPage));
    return _loadFirstPage();
  }

  Future<void> applyQuery(CommunityVideoQuery query) {
    if (_disposed) return Future.value();
    if (query == _state.query && _state.status != FeedStatus.idle) {
      return Future.value();
    }
    _emit(
      CommunityFeedState(query: query, status: FeedStatus.loadingFirstPage),
    );
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
      final pager = _pager = CommunityVideoPager(
        _repository,
        query: _state.query,
        anyTags: _anyTags,
        now: _clock(),
      );
      final page = await _rateLimit.run(
        () => pager.next(cancellation: cancellation),
      );
      if (_disposed || generation != _generation) return;
      if (page.page != 1) {
        throw const ApiFailure(ApiFailureKind.invalidResponse);
      }
      final progress = _progress.accept(
        page.videos,
        continuation: (page.hasMore ? page.page + 1 : null),
      );
      _emit(
        _state.copyWith(
          videos: progress.added,
          page: 1,
          total: page.total,
          failure: progress.stalled
              ? const ApiFailure(ApiFailureKind.paginationStalled)
              : null,
          status: progress.stalled
              ? FeedStatus.stalled
              : page.hasMore
              ? FeedStatus.ready
              : FeedStatus.endOfList,
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
    if (_disposed ||
        _state.isBusy ||
        _state.page == 0 ||
        _state.status == FeedStatus.endOfList) {
      return;
    }
    final generation = _generation;
    final pager = _pager;
    if (pager == null) return;
    final next = _state.page + 1;
    _emit(_state.copyWith(status: FeedStatus.appending, clearFailure: true));
    try {
      final page = await _rateLimit.run(
        () => pager.next(cancellation: _inFlight = RequestCancellation()),
      );
      if (_disposed || generation != _generation) return;
      if (page.page != next) {
        throw const ApiFailure(ApiFailureKind.invalidResponse);
      }
      final progress = _progress.accept(
        page.videos,
        continuation: (page.hasMore ? page.page + 1 : null),
      );
      _emit(
        _state.copyWith(
          videos: List.unmodifiable([..._state.videos, ...progress.added]),
          page: next,
          total: page.total,
          failure: progress.stalled
              ? const ApiFailure(ApiFailureKind.paginationStalled)
              : null,
          status: progress.stalled
              ? FeedStatus.stalled
              : page.hasMore
              ? FeedStatus.ready
              : FeedStatus.endOfList,
        ),
      );
    } on ApiFailure catch (failure) {
      if (_disposed ||
          generation != _generation ||
          failure.kind == ApiFailureKind.cancelled) {
        return;
      }
      _emit(
        _state.copyWith(
          status:
              failure.kind == ApiFailureKind.datasetChanged ||
                  failure.kind == ApiFailureKind.paginationStalled
              ? FeedStatus.stalled
              : FeedStatus.appendFailed,
          failure: failure,
        ),
      );
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
