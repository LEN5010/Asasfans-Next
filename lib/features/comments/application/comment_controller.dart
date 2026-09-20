import 'package:flutter/foundation.dart';
import '../../../core/network/api_failure.dart';
import '../../content/application/fanart_feed_controller.dart' show FeedStatus;
import '../domain/comments.dart';

class CommentController extends ChangeNotifier {
  CommentController(this._repository, this.query);
  final CommentRepository _repository;
  CommentQuery query;
  List<BiliComment> items = const [], pinned = const [];
  BiliComment? root;
  int page = 0;
  int? total;
  bool closed = false;
  FeedStatus status = FeedStatus.idle;
  ApiFailure? failure;
  int generation = 0;
  bool _disposed = false;
  RequestCancellation? _request;
  bool get busy =>
      status == FeedStatus.loadingFirstPage || status == FeedStatus.appending;
  List<BiliComment> get visible {
    final pinIds = pinned.map((c) => c.id).toSet();
    return [...pinned, ...items.where((c) => !pinIds.contains(c.id))];
  }

  Future<void> refresh({CommentOrder? order}) async {
    if (_disposed) return;
    final next = order == null ? query : query.sorted(order);
    if (next != query) {
      items = const [];
      pinned = const [];
      root = null;
      total = null;
      page = 0;
    }
    query = next;
    final current = ++generation;
    _request?.cancel();
    final cancel = _request = RequestCancellation();
    status = FeedStatus.loadingFirstPage;
    failure = null;
    closed = false;
    notifyListeners();
    try {
      final value = await _repository.page(query, cancellation: cancel);
      if (_disposed || current != generation) return;
      _accept(value, first: true);
    } catch (error) {
      if (_disposed || current != generation) return;
      failure = _failure(error);
      status = FeedStatus.failed;
    } finally {
      if (!_disposed && current == generation) notifyListeners();
    }
  }

  Future<void> loadMore({bool automatic = false}) async {
    if (_disposed ||
        busy ||
        (status != FeedStatus.ready &&
            (automatic || status != FeedStatus.appendFailed))) {
      return;
    }
    final current = generation;
    final cancel = _request = RequestCancellation();
    status = FeedStatus.appending;
    failure = null;
    notifyListeners();
    try {
      final value = await _repository.page(
        query,
        page: page + 1,
        cancellation: cancel,
      );
      if (_disposed || current != generation) return;
      _accept(value, first: false);
    } catch (error) {
      if (_disposed || current != generation) return;
      failure = _failure(error);
      status =
          [
            ApiFailureKind.datasetChanged,
            ApiFailureKind.paginationStalled,
          ].contains(failure!.kind)
          ? FeedStatus.stalled
          : FeedStatus.appendFailed;
    } finally {
      if (!_disposed && current == generation) notifyListeners();
    }
  }

  void _accept(CommentPage value, {required bool first}) {
    if (value.page != (first ? 1 : page + 1)) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    if (value.closed) {
      items = const [];
      pinned = const [];
      root = null;
      total = 0;
      page = value.page;
      closed = true;
      status = FeedStatus.endOfList;
      return;
    }
    final known = items.map((c) => c.id).toSet();
    if (!first &&
        (value.total != total ||
            value.items.any((c) => known.contains(c.id)))) {
      throw const ApiFailure(ApiFailureKind.datasetChanged);
    }
    if (value.items.isEmpty && value.hasMore) {
      throw const ApiFailure(ApiFailureKind.paginationStalled);
    }
    items = List.unmodifiable(first ? value.items : [...items, ...value.items]);
    if (first) pinned = value.pinned;
    root = value.root;
    total = value.total;
    page = value.page;
    closed = false;
    status = value.hasMore ? FeedStatus.ready : FeedStatus.endOfList;
  }

  static ApiFailure _failure(Object error) => error is ApiFailure
      ? error
      : const ApiFailure(ApiFailureKind.invalidResponse);
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    generation++;
    _request?.cancel();
    super.dispose();
  }
}
