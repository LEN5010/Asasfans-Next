import 'dart:collection';

import '../../../core/network/api_failure.dart';
import '../../../core/domain/bilibili_id.dart';
import '../../../core/domain/content_identity.dart';
import '../../creator/domain/creator_repository.dart';
import '../../library/domain/library_models.dart';
import '../domain/subscription_updates.dart';

/// Incremental k-way merge. A row is emitted only after every healthy lane has
/// a head or is exhausted. Budget exhaustion preserves frontiers, not a fake end.
class SubscriptionPager {
  SubscriptionPager(
    this._repository,
    SubscriptionRoster roster, {
    this.outputSize = 24,
    this.requestBudget = 6,
  }) : _lanes = roster.creators.map(_Lane.new).toList() {
    if (outputSize < 1 ||
        outputSize > 100 ||
        requestBudget < 1 ||
        requestBudget > 20 ||
        roster.creators.any((c) => !validBilibiliMid(c.mid)) ||
        roster.creators.map((c) => c.mid).toSet().length !=
            roster.creators.length) {
      throw const ApiFailure(ApiFailureKind.invalidRequest);
    }
  }
  final CreatorRepository _repository;
  final int outputSize;
  final int requestBudget;
  List<_Lane> _lanes;
  Set<ContentIdentity> _emitted = {};
  bool _busy = false;

  /// Replay successful cached prefixes, then retry only the failed frontier.
  /// Dataset changes require a full fresh session instead.
  void rewindForRetry() {
    if (_busy) throw const ApiFailure(ApiFailureKind.invalidRequest);
    for (final lane in _lanes) {
      if (lane.failure?.kind == ApiFailureKind.datasetChanged) {
        throw const ApiFailure(ApiFailureKind.datasetChanged);
      }
      lane.buffer
        ..clear()
        ..addAll(lane.history);
      lane.failure = null;
    }
    _emitted = {};
  }

  Future<SubscriptionSlice> next({RequestCancellation? cancellation}) async {
    if (_busy) throw const ApiFailure(ApiFailureKind.invalidRequest);
    _busy = true;
    try {
      _check(cancellation);
      // Cancellation/throw cannot consume already fetched rows invisibly.
      final lanes = _lanes.map((lane) => lane.copy()).toList();
      final seen = {..._emitted};
      final output = <VideoSummary>[];
      var requests = 0;
      var consumed = 0;
      ApiFailure? pause;
      merge:
      while (output.length < outputSize && consumed < 2048) {
        for (final lane in lanes) {
          if (lane.failure != null || lane.buffer.isNotEmpty || !lane.hasMore) {
            continue;
          }
          if (requests == requestBudget) break merge;
          requests++;
          try {
            _check(cancellation);
            final page = await _repository.archives(
              CreatorArchiveQuery(mid: lane.creator.mid),
              page: lane.page + 1,
              cancellation: cancellation,
            );
            _check(cancellation);
            _accept(lane, page);
          } catch (error) {
            _check(cancellation);
            final failure = error is ApiFailure
                ? error
                : const ApiFailure(ApiFailureKind.invalidResponse);
            if (failure.kind == ApiFailureKind.cancelled) rethrow;
            if (failure.kind == ApiFailureKind.rateLimited) {
              pause = failure;
              break merge;
            }
            lane.failure = failure;
          }
        }
        _Lane? best;
        for (final lane in lanes) {
          if (lane.failure == null &&
              lane.buffer.isNotEmpty &&
              (best == null ||
                  _compare(lane.buffer.first, best.buffer.first) < 0)) {
            best = lane;
          }
        }
        if (best == null) break;
        final video = best.buffer.removeFirst();
        consumed++;
        if (seen.add(video.identity)) output.add(video);
      }
      _check(cancellation);
      _lanes = lanes;
      _emitted = seen;
      return SubscriptionSlice(
        items: output,
        issues: [
          for (final lane in lanes)
            if (lane.failure != null)
              SubscriptionIssue(lane.creator, lane.failure!),
        ],
        hasMore: lanes.any(
          (lane) =>
              lane.failure == null && (lane.hasMore || lane.buffer.isNotEmpty),
        ),
        checkedCreators: lanes
            .where((lane) => lane.page > 0 || lane.failure != null)
            .length,
        totalCreators: lanes.length,
        pause: pause,
      );
    } finally {
      _busy = false;
    }
  }

  static void _accept(_Lane lane, CreatorArchivePage page) {
    if (page.page != lane.page + 1 ||
        page.total < 0 ||
        page.items.length > 30 ||
        page.items.length != (page.total - (page.page - 1) * 30).clamp(0, 30) ||
        page.hasMore != (page.page * 30 < page.total)) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    if (lane.total != null && lane.total != page.total) {
      throw const ApiFailure(ApiFailureKind.datasetChanged);
    }
    final ids = <ContentIdentity>{};
    for (final item in page.items) {
      if (item.identity.source != ContentSource.bilibiliVideo ||
          !validBvid(item.identity.value) ||
          item.publishedAt == null) {
        throw const ApiFailure(ApiFailureKind.invalidResponse);
      }
      if (lane.known.contains(item.identity) || !ids.add(item.identity)) {
        throw const ApiFailure(ApiFailureKind.datasetChanged);
      }
    }
    final sorted = [...page.items]..sort(_compare);
    // pubdate allows tied timestamps in arbitrary API order, so the cross-page
    // check compares timestamps only, never assumes a server BVID tie-breaker.
    if (sorted.isNotEmpty &&
        lane.lastTime != null &&
        sorted.first.publishedAt!.isAfter(lane.lastTime!)) {
      throw const ApiFailure(ApiFailureKind.datasetChanged);
    }
    lane.page = page.page;
    lane.total = page.total;
    lane.hasMore = page.hasMore;
    lane.known.addAll(ids);
    lane.history.addAll(sorted);
    lane.buffer.addAll(sorted);
    if (sorted.isNotEmpty) lane.lastTime = sorted.last.publishedAt;
  }

  static int _compare(VideoSummary a, VideoSummary b) {
    final date = b.publishedAt!.compareTo(a.publishedAt!);
    return date != 0 ? date : a.identity.value.compareTo(b.identity.value);
  }

  static void _check(RequestCancellation? cancellation) {
    if (cancellation?.isCancelled == true) {
      throw const ApiFailure(ApiFailureKind.cancelled);
    }
  }
}

class _Lane {
  _Lane(this.creator);
  final LocalSubscription creator;
  final buffer = ListQueue<VideoSummary>();
  final history = <VideoSummary>[];
  final known = <ContentIdentity>{};
  int page = 0;
  int? total;
  bool hasMore = true;
  DateTime? lastTime;
  ApiFailure? failure;
  _Lane copy() => _Lane(creator)
    ..buffer.addAll(buffer)
    ..history.addAll(history)
    ..known.addAll(known)
    ..page = page
    ..total = total
    ..hasMore = hasMore
    ..lastTime = lastTime
    ..failure = failure;
}
