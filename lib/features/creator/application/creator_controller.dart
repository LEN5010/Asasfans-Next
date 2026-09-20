import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_failure.dart';
import '../../content/application/fanart_feed_controller.dart' show FeedStatus;
import '../../content/application/feed_progress.dart';
import '../domain/creator_repository.dart';

class CreatorArchiveState {
  const CreatorArchiveState({
    required this.query,
    this.items = const [],
    this.status = FeedStatus.idle,
    this.failure,
    this.total,
    this.page = 0,
  });
  final CreatorArchiveQuery query;
  final List<VideoSummary> items;
  final FeedStatus status;
  final ApiFailure? failure;
  final int? total;
  final int page;
  bool get busy =>
      status == FeedStatus.loadingFirstPage || status == FeedStatus.appending;
}

class CreatorController extends ChangeNotifier {
  CreatorController(this._repository, this.mid)
    : _archives = CreatorArchiveState(query: CreatorArchiveQuery(mid: mid));
  final CreatorRepository _repository;
  final String mid;
  CreatorProfile? profile;
  ApiFailure? profileFailure;
  bool profileLoading = false;
  CreatorArchiveState _archives;
  CreatorArchiveState get archives => _archives;
  var _profileGeneration = 0;
  var _archiveGeneration = 0;
  int get archiveGeneration => _archiveGeneration;
  bool _closed = false;
  RequestCancellation? _profileRequest;
  RequestCancellation? _archiveRequest;
  final _progress = FeedProgress<VideoSummary>((item) => item.identity);

  Future<void> refresh() async {
    await Future.wait([refreshProfile(), refreshArchives()]);
  }

  Future<void> refreshProfile() async {
    if (_closed) return;
    final generation = ++_profileGeneration;
    _profileRequest?.cancel();
    final cancellation = _profileRequest = RequestCancellation();
    profileLoading = true;
    profileFailure = null;
    notifyListeners();
    try {
      final result = await _repository.profile(mid, cancellation: cancellation);
      if (_closed || generation != _profileGeneration) return;
      profile = result;
    } catch (error) {
      if (_closed || generation != _profileGeneration) return;
      profileFailure = _failure(error);
    } finally {
      if (!_closed && generation == _profileGeneration) {
        profileLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> applyQuery(CreatorArchiveQuery query) {
    if (_closed || query == _archives.query) return Future.value();
    if (query.mid != mid || !query.valid) {
      return Future.error(const ApiFailure(ApiFailureKind.invalidRequest));
    }
    _archives = CreatorArchiveState(query: query);
    return refreshArchives();
  }

  Future<void> refreshArchives() async {
    if (_closed) return;
    final previous = _archives;
    final generation = ++_archiveGeneration;
    _archiveRequest?.cancel();
    final cancellation = _archiveRequest = RequestCancellation();
    _progress.reset();
    _archives = CreatorArchiveState(
      query: previous.query,
      items: previous.items,
      status: FeedStatus.loadingFirstPage,
      total: previous.total,
    );
    notifyListeners();
    try {
      final page = await _repository.archives(
        previous.query,
        cancellation: cancellation,
      );
      if (_closed || generation != _archiveGeneration) return;
      if (page.page != 1) {
        throw const ApiFailure(ApiFailureKind.invalidResponse);
      }
      final accepted = _progress.accept(
        page.items,
        continuation: page.hasMore ? 2 : null,
      );
      _archives = CreatorArchiveState(
        query: previous.query,
        items: accepted.added,
        page: 1,
        total: page.total,
        status: accepted.stalled
            ? FeedStatus.stalled
            : page.hasMore
            ? FeedStatus.ready
            : FeedStatus.endOfList,
        failure: accepted.stalled
            ? const ApiFailure(ApiFailureKind.paginationStalled)
            : null,
      );
    } catch (error) {
      if (_closed || generation != _archiveGeneration) return;
      _archives = CreatorArchiveState(
        query: previous.query,
        items: previous.items,
        total: previous.total,
        status: FeedStatus.failed,
        failure: _failure(error),
      );
    } finally {
      if (!_closed && generation == _archiveGeneration) notifyListeners();
    }
  }

  Future<void> loadMore({bool automatic = false}) async {
    final previous = _archives;
    if (_closed ||
        previous.busy ||
        (previous.status != FeedStatus.ready &&
            (automatic || previous.status != FeedStatus.appendFailed))) {
      return;
    }
    final generation = _archiveGeneration;
    final cancellation = _archiveRequest = RequestCancellation();
    _archives = CreatorArchiveState(
      query: previous.query,
      items: previous.items,
      page: previous.page,
      total: previous.total,
      status: FeedStatus.appending,
    );
    notifyListeners();
    try {
      final page = await _repository.archives(
        previous.query,
        page: previous.page + 1,
        cancellation: cancellation,
      );
      if (_closed || generation != _archiveGeneration) return;
      if (page.page != previous.page + 1) {
        throw const ApiFailure(ApiFailureKind.invalidResponse);
      }
      final known = previous.items.map((item) => item.identity).toSet();
      if (page.total != previous.total ||
          page.items.any((item) => known.contains(item.identity))) {
        throw const ApiFailure(ApiFailureKind.datasetChanged);
      }
      final accepted = _progress.accept(
        page.items,
        continuation: page.hasMore ? page.page + 1 : null,
      );
      _archives = CreatorArchiveState(
        query: previous.query,
        items: List.unmodifiable([...previous.items, ...accepted.added]),
        page: page.page,
        total: page.total,
        status: accepted.stalled
            ? FeedStatus.stalled
            : page.hasMore
            ? FeedStatus.ready
            : FeedStatus.endOfList,
        failure: accepted.stalled
            ? const ApiFailure(ApiFailureKind.paginationStalled)
            : null,
      );
    } catch (error) {
      if (_closed || generation != _archiveGeneration) return;
      final failure = _failure(error);
      _archives = CreatorArchiveState(
        query: previous.query,
        items: previous.items,
        page: previous.page,
        total: previous.total,
        status: failure.kind == ApiFailureKind.datasetChanged
            ? FeedStatus.stalled
            : FeedStatus.appendFailed,
        failure: failure,
      );
    } finally {
      if (!_closed && generation == _archiveGeneration) notifyListeners();
    }
  }

  static ApiFailure _failure(Object error) => error is ApiFailure
      ? error
      : const ApiFailure(ApiFailureKind.invalidResponse);
  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    _profileGeneration++;
    _archiveGeneration++;
    _profileRequest?.cancel();
    _archiveRequest?.cancel();
    super.dispose();
  }
}
