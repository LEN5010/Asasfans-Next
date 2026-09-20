import 'api_failure.dart';

/// One gate per transport origin, shared by all routes using that client.
/// Fail fast during cooldown: queued retries must not wake up as a burst.
class RateLimitGate {
  RateLimitGate({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  DateTime? _until;
  int _consecutiveLimits = 0;

  Future<T> run<T>(Future<T> Function() request) async {
    final until = _until;
    if (until != null && until.isAfter(_clock())) {
      throw _failure(until);
    }
    try {
      final result = await request();
      // A concurrent older success must not erase a newer 429's deadline.
      if (_until == null || !_until!.isAfter(_clock())) {
        _consecutiveLimits = 0;
      }
      return result;
    } on ApiFailure catch (failure) {
      if (failure.kind != ApiFailureKind.rateLimited) rethrow;
      final fallback = Duration(seconds: 30 * (1 << _consecutiveLimits));
      if (_consecutiveLimits < 4) _consecutiveLimits++;
      final now = _clock();
      final delay = failure.retryAfter;
      final requested =
          failure.retryAt ??
          now.add(delay != null && delay > Duration.zero ? delay : fallback);
      final deadline = requested.isAfter(now) ? requested : now.add(fallback);
      if (_until == null || deadline.isAfter(_until!)) _until = deadline;
      throw _failure(_until!);
    }
  }

  ApiFailure _failure(DateTime until) => ApiFailure(
    ApiFailureKind.rateLimited,
    retryAt: until,
    retryAfter: until.difference(_clock()),
  );
}
