import 'dart:collection';

import '../../../core/domain/content_identity.dart';
import '../../../core/network/api_failure.dart';
import '../domain/community_video_repository.dart';

/// Per-feed paging session. Source queries use verified AND syntax; channel
/// alternatives are merged here without assuming server-side tag OR support.
class CommunityVideoPager {
  CommunityVideoPager(
    this._repository, {
    required CommunityVideoQuery query,
    List<String> anyTags = const [],
    required DateTime now,
    this.pageSize = 20,
  }) : _query = query.copyWith(
         tags: List.unmodifiable(query.tags.toSet().toList()..sort()),
         asOf: (query.asOf ?? now).toUtc(),
       ),
       _alternatives = List.unmodifiable(anyTags.toSet().toList()..sort()) {
    if (pageSize < 1 ||
        pageSize > 50 ||
        _alternatives.length > 8 ||
        !_query.isServerAcceptable ||
        !CommunityVideoQuery(tags: _alternatives).isServerAcceptable) {
      throw const ApiFailure(ApiFailureKind.invalidRequest);
    }
    _lanes = [
      if (_alternatives.isEmpty)
        _Lane(_query)
      else
        for (final tag in _alternatives)
          _Lane(_query.copyWith(tags: {..._query.tags, tag}.toList())),
    ];
  }

  final CommunityVideoRepository _repository;
  final CommunityVideoQuery _query;
  final List<String> _alternatives;
  final int pageSize;
  late List<_Lane> _lanes;
  Set<ContentIdentity> _seen = {};
  int _page = 0;
  bool _busy = false;

  Future<CommunityVideoPage> next({RequestCancellation? cancellation}) async {
    if (_busy) throw const ApiFailure(ApiFailureKind.invalidRequest);
    _busy = true;
    try {
      _checkCancelled(cancellation);
      // Latest videos or one exact tag need no merge or artificial rank key.
      if (_lanes.length == 1) {
        final result = await _repository.videos(
          query: _lanes.single.query,
          page: _page + 1,
          cancellation: cancellation,
        );
        _checkCancelled(cancellation);
        if (result.page != _page + 1) {
          throw const ApiFailure(ApiFailureKind.invalidResponse);
        }
        _page++;
        return result;
      }

      // A failed/cancelled lane must not partially consume another lane.
      // Retry starts from the last committed output page with no lost rows.
      final lanes = _lanes.map((lane) => lane.copy()).toList();
      final seen = {..._seen};
      final output = <CommunityVideo>[];
      var requestBudget = 16;
      var consumedBudget = pageSize * 16;
      while (output.length < pageSize) {
        _checkCancelled(cancellation);
        for (final lane in lanes) {
          while (lane.buffer.isEmpty && lane.hasMore) {
            if (--requestBudget < 0) {
              throw const ApiFailure(ApiFailureKind.paginationStalled);
            }
            final page = await _repository.videos(
              query: lane.query,
              page: lane.page + 1,
              cancellation: cancellation,
            );
            _checkCancelled(cancellation);
            if (page.page != lane.page + 1) {
              throw const ApiFailure(ApiFailureKind.invalidResponse);
            }
            final sorted = [...page.videos];
            // All sort keys must exist; unknown score is not zero, and an
            // unknown publication date must not fabricate a stable ordering.
            for (final video in sorted) {
              _rank(video);
            }
            sorted.sort((a, b) {
              final rank = _rank(b).compareTo(_rank(a));
              return rank != 0
                  ? rank
                  : a.identity.storageKey.compareTo(b.identity.storageKey);
            });
            if (sorted.isNotEmpty &&
                lane.lastRank != null &&
                _rank(sorted.first) > lane.lastRank!) {
              throw const ApiFailure(ApiFailureKind.datasetChanged);
            }
            if (sorted.isNotEmpty) lane.lastRank = _rank(sorted.last);
            lane.page = page.page;
            lane.hasMore = page.hasMore;
            lane.buffer.addAll(sorted);
            lane.emptyPages = sorted.isEmpty ? lane.emptyPages + 1 : 0;
            if (lane.emptyPages >= 3 && lane.hasMore) {
              throw const ApiFailure(ApiFailureKind.paginationStalled);
            }
          }
        }
        _Lane? best;
        for (final lane in lanes) {
          if (lane.buffer.isNotEmpty &&
              (best == null ||
                  _rank(lane.buffer.first) > _rank(best.buffer.first))) {
            best = lane;
          }
        }
        if (best == null) break;
        if (--consumedBudget < 0) {
          throw const ApiFailure(ApiFailureKind.paginationStalled);
        }
        final video = best.buffer.removeFirst();
        if (seen.add(video.identity)) output.add(video);
      }
      _checkCancelled(cancellation);
      _lanes = lanes;
      _seen = seen;
      _page++;
      return CommunityVideoPage(
        videos: List.unmodifiable(output),
        page: _page,
        hasMore: lanes.any((lane) => lane.hasMore || lane.buffer.isNotEmpty),
        // Source totals overlap. Summing them would invent a union total.
      );
    } finally {
      _busy = false;
    }
  }

  num _rank(CommunityVideo video) {
    final value = switch (_query.order) {
      CommunityVideoOrder.newest => video.publishedAt?.millisecondsSinceEpoch,
      CommunityVideoOrder.score => video.rankScore,
    };
    if (value == null || !value.isFinite) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    return value;
  }

  static void _checkCancelled(RequestCancellation? cancellation) {
    if (cancellation?.isCancelled ?? false) {
      throw const ApiFailure(ApiFailureKind.cancelled);
    }
  }
}

class _Lane {
  _Lane(this.query);
  final CommunityVideoQuery query;
  final buffer = ListQueue<CommunityVideo>();
  int page = 0;
  bool hasMore = true;
  num? lastRank;
  int emptyPages = 0;

  _Lane copy() => _Lane(query)
    ..buffer.addAll(buffer)
    ..page = page
    ..hasMore = hasMore
    ..lastRank = lastRank
    ..emptyPages = emptyPages;
}
