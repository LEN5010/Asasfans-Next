import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import '../domain/bilibili_id.dart';
import '../domain/request_cancellation.dart';
import '../network/api_failure.dart';
import '../network/public_api_client.dart';
import '../network/rate_limit_gate.dart';
import 'bili_credentials.dart';
import 'bili_media_policy.dart';

class MediaByteRange {
  const MediaByteRange._(this.start, this.end, this.suffix);
  final int? start, end, suffix;
  static MediaByteRange? parse(String? raw) {
    if (raw == null) return null;
    if (raw.length > 64) throw const ApiFailure(ApiFailureKind.invalidRequest);
    final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(raw);
    if (match == null || (match[1]!.isEmpty && match[2]!.isEmpty)) {
      throw const ApiFailure(ApiFailureKind.invalidRequest);
    }
    int? integer(String raw) {
      if (raw.isEmpty) return null;
      final value = int.tryParse(raw);
      if (value == null || value < 0 || value > 9007199254740991) {
        throw const ApiFailure(ApiFailureKind.invalidRequest);
      }
      return value;
    }

    final first = integer(match[1]!);
    final last = integer(match[2]!);
    if ((first == null && last == 0) ||
        (first != null && last != null && first > last)) {
      throw const ApiFailure(ApiFailureKind.invalidRequest);
    }
    return first == null
        ? MediaByteRange._(null, null, last)
        : MediaByteRange._(first, last, null);
  }

  String get wire =>
      suffix == null ? 'bytes=$start-${end ?? ''}' : 'bytes=-$suffix';
}

/// Streaming metadata only: never exposes redirect locations, cookies, or a
/// full Dio response. The consumer must listen or close, and owns backpressure.
class BiliMediaBody {
  BiliMediaBody._({
    required this.status,
    required this.contentType,
    required this.contentLength,
    required this.contentRange,
    required ResponseBody body,
    required this.expectedBytes,
    required Duration idleTimeout,
    required CancelToken token,
    required void Function() released,
  }) : _body = body,
       _idleTimeout = idleTimeout,
       _token = token,
       _released = released {
    _controller = StreamController<List<int>>(
      sync: true,
      onListen: _listen,
      onPause: () => _subscription?.pause(),
      onResume: () => _subscription?.resume(),
      onCancel: () => _finish(),
    );
    unawaited(
      _token.whenCancel.then(
        (_) => _finish(error: const ApiFailure(ApiFailureKind.cancelled)),
      ),
    );
  }
  final int status;
  final String contentType;
  final int? contentLength;
  final String? contentRange;
  final int? expectedBytes;
  final ResponseBody _body;
  final Duration _idleTimeout;
  final CancelToken _token;
  final void Function() _released;
  late final StreamController<List<int>> _controller;
  StreamSubscription<Uint8List>? _subscription;
  bool _finished = false, _listened = false;
  int _bytes = 0;
  Stream<List<int>> get bytes => _controller.stream;
  void _listen() {
    if (_finished) return;
    _listened = true;
    _subscription = _body.stream
        .where((chunk) => chunk.isNotEmpty)
        .timeout(_idleTimeout)
        .listen(
          (chunk) {
            if (_finished) return;
            _bytes += chunk.length;
            if (expectedBytes != null && _bytes > expectedBytes!) {
              unawaited(
                _finish(
                  error: const ApiFailure(ApiFailureKind.invalidResponse),
                ),
              );
              return;
            }
            _controller.add(chunk);
          },
          onError: (Object error, StackTrace stack) {
            unawaited(
              _finish(
                error: _token.isCancelled
                    ? const ApiFailure(ApiFailureKind.cancelled)
                    : BiliMediaTransport.failure(error),
              ),
            );
          },
          onDone: () {
            unawaited(
              _finish(
                error: expectedBytes != null && _bytes != expectedBytes
                    ? const ApiFailure(ApiFailureKind.invalidResponse)
                    : null,
              ),
            );
          },
          cancelOnError: false,
        );
    if (_finished) unawaited(_subscription!.cancel());
  }

  Future<void> _finish({ApiFailure? error}) async {
    if (_finished) return;
    _finished = true;
    _released();
    _token.cancel();
    if (error != null) _controller.addError(error, StackTrace.empty);
    // Do not await controller.close(): a paused consumer may otherwise keep
    // credentials/requests alive indefinitely while the player is disposed.
    unawaited(_controller.close());
    try {
      if (_listened) {
        await _subscription?.cancel();
      } else {
        await _body.stream
            .listen((_) {}, onError: (Object _, StackTrace _) {})
            .cancel();
      }
    } catch (_) {}
  }

  Future<void> close() =>
      _finish(error: const ApiFailure(ApiFailureKind.cancelled));
  @override
  String toString() => 'BiliMediaBody($status, redacted)';
}

/// Private GET/HEAD-only transport. No whole-call deadline: a video may stay
/// open for hours. Connect/receive inactivity and each redirect are bounded.
class BiliMediaTransport {
  BiliMediaTransport({
    BiliCredentials? Function()? credentials,
    HttpClientAdapter? adapter,
    DateTime Function()? clock,
    this.idleTimeout = const Duration(seconds: 30),
    this.maxConcurrent = 16,
  }) : _credentials = credentials,
       _clock = clock ?? DateTime.now,
       _gate = RateLimitGate(clock: clock),
       _adapter =
           adapter ??
           IOHttpClientAdapter(
             createHttpClient: () => HttpClient()..autoUncompress = false,
           );
  // Do not use Dio.request here: its high-level response wrapper subscribes
  // eagerly and does not propagate downstream pause to the source stream.
  final HttpClientAdapter _adapter;
  final BiliCredentials? Function()? _credentials;
  final DateTime Function() _clock;
  final RateLimitGate _gate;
  final Duration idleTimeout;
  final int maxConcurrent;
  final _requests = <CancelToken>{};
  bool _closed = false;

  Future<BiliMediaBody> open(
    Uri location, {
    required String bvid,
    String? range,
    bool head = false,
    RequestCancellation? cancellation,
  }) => _gate.run(() async {
    _check(cancellation);
    if (!validBvid(bvid) || !BiliMediaPolicy.allowed(location)) {
      throw const ApiFailure(ApiFailureKind.invalidRequest);
    }
    final requested = MediaByteRange.parse(range);
    if (_requests.length >= maxConcurrent) {
      throw const ApiFailure(ApiFailureKind.unavailable, code: 'MEDIA_BUSY');
    }
    final token = CancelToken();
    _requests.add(token);
    final detach = cancellation?.onCancel(() => token.cancel());
    var transferred = false;
    ResponseBody? unread;
    try {
      var uri = location;
      final visited = <Uri>{};
      for (var hop = 0; hop <= 5; hop++) {
        _check(cancellation);
        if (!BiliMediaPolicy.allowed(uri) || !visited.add(uri)) {
          throw const ApiFailure(
            ApiFailureKind.forbidden,
            code: 'MEDIA_REDIRECT_REJECTED',
          );
        }
        final options = RequestOptions(
          path: uri.toString(),
          cancelToken: token,
          connectTimeout: const Duration(seconds: 12),
          method: head ? 'HEAD' : 'GET',
          responseType: ResponseType.stream,
          receiveTimeout: idleTimeout,
          sendTimeout: const Duration(seconds: 12),
          followRedirects: false,
          maxRedirects: 0,
          validateStatus: (_) => true,
          headers: BiliMediaPolicy.headers(
            uri,
            bvid,
            _credentials?.call(),
            range: requested?.wire,
          ),
        );
        var cancelled = false;
        final response = await Future.any<ResponseBody>([
          _adapter.fetch(options, null, token.whenCancel).then((value) {
            if (cancelled) {
              unawaited(_discard(value));
              throw const ApiFailure(ApiFailureKind.cancelled);
            }
            return value;
          }),
          token.whenCancel.then((_) {
            cancelled = true;
            throw const ApiFailure(ApiFailureKind.cancelled);
          }),
        ]);
        unread = response;
        _check(cancellation);
        final status = response.statusCode;
        final headers = Headers.fromMap(response.headers);
        if ([301, 302, 303, 307, 308].contains(status)) {
          final locations = headers['location'];
          if (locations == null ||
              locations.length != 1 ||
              locations.single.length > 16384) {
            throw const ApiFailure(ApiFailureKind.invalidResponse);
          }
          final target = uri.resolve(locations.single);
          await _discard(unread);
          unread = null;
          if (hop == 5 || !BiliMediaPolicy.allowed(target)) {
            throw const ApiFailure(
              ApiFailureKind.forbidden,
              code: 'MEDIA_REDIRECT_REJECTED',
            );
          }
          uri = target;
          continue;
        }
        if (status != 200 && status != 206) {
          if (status == 429) {
            throw ApiFailure(
              ApiFailureKind.rateLimited,
              retryAfter: PublicApiClient.parseRetryAfter(
                headers.value('retry-after'),
                now: _clock(),
              ),
            );
          }
          throw ApiFailure(switch (status) {
            401 => ApiFailureKind.loginRequired,
            403 => ApiFailureKind.forbidden,
            404 || 410 => ApiFailureKind.notFound,
            412 => ApiFailureKind.riskControl,
            416 => ApiFailureKind.invalidRequest,
            _ => ApiFailureKind.unavailable,
          }, code: 'HTTP_$status');
        }
        final type =
            (headers.value('content-type') ?? 'application/octet-stream')
                .split(';')
                .first
                .trim()
                .toLowerCase();
        if (![
          'video/mp4',
          'audio/mp4',
          'application/octet-stream',
        ].contains(type)) {
          throw const ApiFailure(ApiFailureKind.invalidResponse);
        }
        final encoding = headers.value('content-encoding');
        if (encoding != null && encoding.toLowerCase() != 'identity') {
          throw const ApiFailure(ApiFailureKind.invalidResponse);
        }
        final lengthRaw = headers.value('content-length');
        final length = lengthRaw == null ? null : _number(lengthRaw);
        final contentRange = headers.value('content-range');
        var bodyLength = length;
        if (status == 206) {
          bodyLength = _validateRange(contentRange, requested, length);
        } else if (contentRange != null) {
          throw const ApiFailure(ApiFailureKind.invalidResponse);
        }
        _check(cancellation);
        final body = BiliMediaBody._(
          status: status,
          contentType: type,
          contentLength: bodyLength,
          contentRange: contentRange,
          body: unread,
          expectedBytes: head ? 0 : bodyLength,
          idleTimeout: idleTimeout,
          token: token,
          released: () {
            _requests.remove(token);
            detach?.call();
          },
        );
        unread = null;
        transferred = true;
        return body;
      }
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    } catch (error) {
      if (token.isCancelled || _closed || cancellation?.isCancelled == true) {
        throw const ApiFailure(ApiFailureKind.cancelled);
      }
      throw failure(error);
    } finally {
      if (unread != null) await _discard(unread);
      if (!transferred) {
        _requests.remove(token);
        detach?.call();
        token.cancel();
      }
    }
  });

  static int _number(String value) {
    if (!RegExp(r'^\d{1,16}$').hasMatch(value)) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    final number = int.parse(value);
    if (number > 9007199254740991) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    return number;
  }

  static int _validateRange(
    String? raw,
    MediaByteRange? requested,
    int? length,
  ) {
    final match = raw == null
        ? null
        : RegExp(r'^bytes (\d+)-(\d+)/(\d+|\*)$').firstMatch(raw);
    if (match == null || requested == null) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    final start = _number(match[1]!);
    final end = _number(match[2]!);
    final total = match[3] == '*' ? null : _number(match[3]!);
    if (start > end ||
        (total != null && end >= total) ||
        (length != null && length != end - start + 1) ||
        (requested.start != null && requested.start != start) ||
        (requested.end != null && end > requested.end!) ||
        (requested.suffix != null &&
            (end - start + 1 > requested.suffix! ||
                (total != null &&
                    (end != total - 1 ||
                        start !=
                            (total - requested.suffix!).clamp(0, total)))))) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    return end - start + 1;
  }

  static Future<void> _discard(ResponseBody body) async {
    try {
      await body.stream
          .listen((_) {}, onError: (Object _, StackTrace _) {})
          .cancel();
    } catch (_) {}
  }

  void _check(RequestCancellation? cancellation) {
    if (_closed || cancellation?.isCancelled == true) {
      throw const ApiFailure(ApiFailureKind.cancelled);
    }
  }

  static ApiFailure failure(Object error) {
    if (error is ApiFailure) return error;
    if (error is TimeoutException) {
      return const ApiFailure(ApiFailureKind.timeout);
    }
    if (error is SocketException || error is HandshakeException) {
      return const ApiFailure(ApiFailureKind.offline);
    }
    if (error is DioException) {
      return ApiFailure(switch (error.type) {
        DioExceptionType.cancel => ApiFailureKind.cancelled,
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout => ApiFailureKind.timeout,
        _ => ApiFailureKind.offline,
      });
    }
    return const ApiFailure(ApiFailureKind.invalidResponse);
  }

  void close() {
    if (_closed) return;
    _closed = true;
    for (final token in _requests.toList()) {
      token.cancel();
    }
    _adapter.close(force: true);
  }
}
