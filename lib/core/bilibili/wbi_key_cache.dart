import 'dart:async';

import '../domain/request_cancellation.dart';
import '../network/api_failure.dart';
import 'wbi_signer.dart';

/// Shared nav request with per-waiter cancellation. One cancelled page cannot
/// cancel another page's waiter; the last waiter aborts the actual request.
class WbiKeyCache {
  WbiKeyCache(
    this._load, {
    DateTime Function()? clock,
    this.ttl = const Duration(hours: 1),
  }) : _clock = clock ?? DateTime.now;
  final Future<WbiKeys> Function(RequestCancellation) _load;
  final DateTime Function() _clock;
  final Duration ttl;
  WbiKeys? _keys;
  DateTime? _fetchedAt;
  _Flight? _flight;
  bool _closed = false;

  Future<WbiKeys> get(RequestCancellation? cancellation) async {
    _check(cancellation);
    final age = _fetchedAt == null ? null : _clock().difference(_fetchedAt!);
    if (_keys != null && age != null && age >= Duration.zero && age < ttl) {
      return _keys!;
    }
    var flight = _flight;
    if (flight == null) {
      flight = _Flight();
      _flight = flight;
      flight.result = _fetch(flight);
    }
    flight.waiters++;
    try {
      final result = await _wait(
        _wait(flight.result, flight.cancellation),
        cancellation,
      );
      _check(cancellation);
      return result;
    } finally {
      flight.waiters--;
      if (flight.waiters == 0 && !flight.finished) {
        flight.cancellation.cancel();
        if (identical(_flight, flight)) _flight = null;
      }
    }
  }

  Future<WbiKeys> _fetch(_Flight flight) async {
    try {
      final keys = await _load(flight.cancellation);
      if (!_closed &&
          !flight.cancellation.isCancelled &&
          identical(_flight, flight)) {
        _keys = keys;
        _fetchedAt = _clock();
      }
      if (flight.cancellation.isCancelled) {
        throw const ApiFailure(ApiFailureKind.cancelled);
      }
      return keys;
    } finally {
      flight.finished = true;
      if (identical(_flight, flight)) _flight = null;
    }
  }

  void invalidate() {
    _keys = null;
    _fetchedAt = null;
  }

  void close() {
    _closed = true;
    invalidate();
    _flight?.cancellation.cancel();
    _flight = null;
  }

  void _check(RequestCancellation? cancellation) {
    if (_closed || cancellation?.isCancelled == true) {
      throw const ApiFailure(ApiFailureKind.cancelled);
    }
  }
}

class _Flight {
  final cancellation = RequestCancellation();
  late final Future<WbiKeys> result;
  int waiters = 0;
  bool finished = false;
}

Future<T> _wait<T>(Future<T> source, RequestCancellation? cancellation) {
  if (cancellation == null) return source;
  final result = Completer<T>();
  source.then(
    (value) {
      if (!result.isCompleted) result.complete(value);
    },
    onError: (Object error, StackTrace stack) {
      if (!result.isCompleted) result.completeError(error, stack);
    },
  );
  cancellation.onCancel(() {
    if (!result.isCompleted) {
      result.completeError(const ApiFailure(ApiFailureKind.cancelled));
    }
  });
  return result.future;
}
