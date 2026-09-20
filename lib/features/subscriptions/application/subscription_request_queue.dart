import 'dart:async';

import '../../../core/network/api_failure.dart';
import '../../creator/domain/creator_repository.dart';

/// Shared across update pages: one archive request at a time, with a minimum
/// gap after completion. No automatic retries; metadata still owns 429 gates.
class SubscriptionRequestQueue implements CreatorRepository {
  SubscriptionRequestQueue(
    this._source, {
    this.gap = const Duration(milliseconds: 400),
  });
  final CreatorRepository _source;
  final Duration gap;
  Future<void> _tail = Future.value();
  final _clock = Stopwatch()..start();
  Duration _next = Duration.zero;
  @override
  Future<CreatorProfile> profile(
    String mid, {
    RequestCancellation? cancellation,
  }) => _source.profile(mid, cancellation: cancellation);
  @override
  Future<CreatorArchivePage> archives(
    CreatorArchiveQuery query, {
    int page = 1,
    RequestCancellation? cancellation,
  }) {
    final result = _tail.then((_) async {
      _check(cancellation);
      final delay = _next - _clock.elapsed;
      if (delay > Duration.zero) await _delay(delay, cancellation);
      _check(cancellation);
      try {
        return await _source.archives(
          query,
          page: page,
          cancellation: cancellation,
        );
      } finally {
        _next = _clock.elapsed + gap;
      }
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  static void _check(RequestCancellation? cancellation) {
    if (cancellation?.isCancelled == true) {
      throw const ApiFailure(ApiFailureKind.cancelled);
    }
  }

  static Future<void> _delay(
    Duration duration,
    RequestCancellation? cancellation,
  ) async {
    final completed = Completer<void>();
    final timer = Timer(duration, completed.complete);
    cancellation?.onCancel(() {
      timer.cancel();
      if (!completed.isCompleted) completed.complete();
    });
    await completed.future;
  }
}
