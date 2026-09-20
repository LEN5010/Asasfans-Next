import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../domain/request_cancellation.dart';
import '../network/api_failure.dart';
import '../network/public_api_client.dart';
import '../network/rate_limit_gate.dart';
import 'wbi_key_cache.dart';
import 'wbi_signer.dart';
import 'bili_credentials.dart';

enum BiliReadEndpoint {
  nav('/x/web-interface/nav', false),
  card('/x/web-interface/card', false),
  archives('/x/space/wbi/arc/search', true),
  video('/x/web-interface/view', false),
  comments('/x/v2/reply', false),
  commentReplies('/x/v2/reply/reply', false),
  playUrl('/x/player/wbi/playurl', true);

  const BiliReadEndpoint(this.path, this.signed);
  final String path;
  final bool signed;
}

abstract interface class BiliReadGateway {
  Future<Map<String, Object?>> get(
    BiliReadEndpoint endpoint, {
    Map<String, String> parameters = const {},
    RequestCancellation? cancellation,
  });
}

/// Dedicated GET-only metadata boundary. Fixed HTTPS origin and
/// allowlisted paths; never a community client, login WebView or media loader.
/// Optional current account credentials are scoped to this trusted origin;
/// session replacement disposes the client. Other sites/media never share it.
class BiliMetadataClient implements BiliReadGateway {
  BiliMetadataClient({
    HttpClientAdapter? adapter,
    BiliCredentials? Function()? credentials,
    DateTime Function()? clock,
    this.requestTimeout = const Duration(seconds: 20),
  }) : _credentials = credentials,
       _clock = clock ?? DateTime.now,
       _gate = RateLimitGate(clock: clock),
       _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 12))) {
    if (adapter != null) _dio.httpClientAdapter = adapter;
    _keys = WbiKeyCache((cancellation) async {
      final data = await _request(
        BiliReadEndpoint.nav,
        query: '',
        cancellation: cancellation,
      );
      final wbi = data['wbi_img'];
      if (wbi is! Map ||
          wbi['img_url'] is! String ||
          wbi['sub_url'] is! String) {
        throw const ApiFailure(ApiFailureKind.invalidResponse);
      }
      return WbiKeys.fromUrls(
        wbi['img_url'] as String,
        wbi['sub_url'] as String,
      );
    }, clock: _clock);
  }
  final Dio _dio;
  final BiliCredentials? Function()? _credentials;
  final Duration requestTimeout;
  final DateTime Function() _clock;
  final RateLimitGate _gate;
  late final WbiKeyCache _keys;
  final _requests = <CancelToken>{};
  bool _closed = false;
  static const maxBytes = 2 * 1024 * 1024;
  static const userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  @override
  Future<Map<String, Object?>> get(
    BiliReadEndpoint endpoint, {
    Map<String, String> parameters = const {},
    RequestCancellation? cancellation,
  }) async {
    _check(cancellation);
    final query = endpoint.signed
        ? (await _keys.get(cancellation)).sign(parameters, _clock())
        : WbiKeys.encode(parameters);
    _check(cancellation);
    try {
      return await _request(endpoint, query: query, cancellation: cancellation);
    } on ApiFailure catch (error) {
      if (endpoint.signed && error.kind == ApiFailureKind.riskControl) {
        _keys.invalidate();
      }
      rethrow;
    }
  }

  Future<Map<String, Object?>> _request(
    BiliReadEndpoint endpoint, {
    required String query,
    RequestCancellation? cancellation,
  }) => _gate.run(() async {
    _check(cancellation);
    final token = CancelToken();
    _requests.add(token);
    cancellation?.onCancel(token.cancel);
    var timedOut = false;
    final deadline = Timer(requestTimeout, () {
      timedOut = true;
      token.cancel();
    });
    try {
      final uri = Uri(
        scheme: 'https',
        host: 'api.bilibili.com',
        path: endpoint.path,
        query: query.isEmpty ? null : query,
      );
      final response = await _dio.getUri<ResponseBody>(
        uri,
        cancelToken: token,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
          maxRedirects: 0,
          validateStatus: (_) => true,
          receiveTimeout: const Duration(seconds: 12),
          sendTimeout: const Duration(seconds: 12),
          headers: {
            'Accept': 'application/json',
            'User-Agent': userAgent,
            'Referer': 'https://www.bilibili.com/',
            if (_credentials?.call()?.metadataHeader(uri)
                case final String cookie)
              'Cookie': cookie,
          },
        ),
      );
      _check(cancellation);
      final body = response.data;
      if (body == null) throw const ApiFailure(ApiFailureKind.invalidResponse);
      final status = response.statusCode;
      if (status != 200) {
        await body.stream.listen((_) {}).cancel();
        if (status == 429) {
          throw ApiFailure(
            ApiFailureKind.rateLimited,
            retryAfter: PublicApiClient.parseRetryAfter(
              response.headers.value('retry-after'),
              now: _clock(),
            ),
          );
        }
        if (status == 412) throw const ApiFailure(ApiFailureKind.riskControl);
        if (status == 401) throw const ApiFailure(ApiFailureKind.loginRequired);
        if (status == 403) throw const ApiFailure(ApiFailureKind.forbidden);
        if (status == 404) throw const ApiFailure(ApiFailureKind.notFound);
        throw const ApiFailure(ApiFailureKind.unavailable);
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in body.stream.timeout(
        const Duration(seconds: 12),
      )) {
        _check(cancellation);
        if (timedOut) throw const ApiFailure(ApiFailureKind.timeout);
        if (bytes.length + chunk.length > maxBytes) {
          token.cancel();
          throw const ApiFailure(ApiFailureKind.invalidResponse);
        }
        bytes.add(chunk);
      }
      _check(cancellation);
      if (timedOut) throw const ApiFailure(ApiFailureKind.timeout);
      final raw = jsonDecode(utf8.decode(bytes.takeBytes()));
      if (raw is! Map<String, dynamic> || raw['code'] is! int) {
        throw const ApiFailure(ApiFailureKind.invalidResponse);
      }
      final code = raw['code'] as int;
      if (code != 0 && !(endpoint == BiliReadEndpoint.nav && code == -101)) {
        throw _business(code);
      }
      final data = raw['data'];
      if (data is! Map<String, dynamic>) {
        throw const ApiFailure(ApiFailureKind.invalidResponse);
      }
      if (data['v_voucher'] != null ||
          data['is_risk'] == true ||
          (data['gaia_res_type'] is num &&
              (data['gaia_res_type'] as num) > 0)) {
        throw const ApiFailure(ApiFailureKind.riskControl);
      }
      return Map<String, Object?>.from(data);
    } on ApiFailure {
      rethrow;
    } on TimeoutException {
      throw const ApiFailure(ApiFailureKind.timeout);
    } on FormatException {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    } on DioException catch (error) {
      if (timedOut) throw const ApiFailure(ApiFailureKind.timeout);
      if (error.type == DioExceptionType.cancel) {
        throw const ApiFailure(ApiFailureKind.cancelled);
      }
      if ([
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.sendTimeout,
      ].contains(error.type)) {
        throw const ApiFailure(ApiFailureKind.timeout);
      }
      throw const ApiFailure(ApiFailureKind.offline);
    } catch (_) {
      if (timedOut) throw const ApiFailure(ApiFailureKind.timeout);
      _check(cancellation);
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    } finally {
      deadline.cancel();
      token.cancel();
      _requests.remove(token);
    }
  });
  static ApiFailure _business(int code) => ApiFailure(switch (code) {
    -101 || -658 => ApiFailureKind.loginRequired,
    -352 || -412 => ApiFailureKind.riskControl,
    -509 || -799 => ApiFailureKind.rateLimited,
    -404 || -626 => ApiFailureKind.notFound,
    -403 ||
    -102 ||
    12002 ||
    62002 ||
    62004 ||
    62012 => ApiFailureKind.forbidden,
    -400 => ApiFailureKind.invalidRequest,
    _ => ApiFailureKind.unavailable,
  }, code: '$code');
  void _check(RequestCancellation? cancellation) {
    if (_closed || cancellation?.isCancelled == true) {
      throw const ApiFailure(ApiFailureKind.cancelled);
    }
  }

  void close() {
    _closed = true;
    _keys.close();
    for (final token in _requests.toList()) {
      token.cancel();
    }
    _requests.clear();
    _dio.close(force: true);
  }
}
