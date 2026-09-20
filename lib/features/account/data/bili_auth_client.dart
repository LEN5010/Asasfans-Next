import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';

import '../../../core/bilibili/bili_metadata_client.dart'
    show BiliMetadataClient;
import '../../../core/network/api_failure.dart';
import '../../../core/network/public_api_client.dart';
import '../../../core/network/rate_limit_gate.dart';
import '../domain/bili_account.dart';

/// Owns only auth/nav requests. No shared cookie jar, redirects, interceptors,
/// cookie-bearing browser navigation or requests to the QR crossDomain URL.
class BiliAuthClient implements BiliAuthGateway {
  BiliAuthClient({
    HttpClientAdapter? adapter,
    DateTime Function()? clock,
    this.deadline = const Duration(seconds: 20),
  }) : _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 12))),
       _clock = clock ?? DateTime.now,
       _gate = RateLimitGate(clock: clock) {
    if (adapter != null) _dio.httpClientAdapter = adapter;
  }
  final Dio _dio;
  final DateTime Function() _clock;
  final RateLimitGate _gate;
  final Duration deadline;
  final _requests = <CancelToken>{};
  bool _closed = false;
  @override
  Future<BiliQrTicket> createQr({RequestCancellation? cancellation}) async {
    final data = (await _get(
      Uri.https(
        'passport.bilibili.com',
        '/x/passport-login/web/qrcode/generate',
      ),
      cancellation: cancellation,
    )).data;
    return _parseTicket(data);
  }

  static BiliQrTicket _parseTicket(Map<String, dynamic> data) {
    try {
      final key = data['qrcode_key'];
      final url = data['url'] is String
          ? Uri.tryParse(data['url'] as String)
          : null;
      if (key is! String ||
          !RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(key) ||
          url == null ||
          url.scheme != 'https' ||
          url.host != 'passport.bilibili.com' ||
          url.port != 443 ||
          url.userInfo.isNotEmpty ||
          url.path != '/h5-app/passport/login/scan' ||
          url.queryParametersAll['qrcode_key']?.length != 1 ||
          url.queryParameters['qrcode_key'] != key ||
          url.toString().length > 4096) {
        throw const ApiFailure(ApiFailureKind.invalidResponse);
      }
      return BiliQrTicket(key: key, url: url);
    } on ApiFailure {
      rethrow;
    } catch (_) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
  }

  @override
  Future<BiliQrResult> poll(
    BiliQrTicket ticket, {
    RequestCancellation? cancellation,
  }) async {
    if (!RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(ticket.key)) {
      throw const ApiFailure(ApiFailureKind.invalidRequest);
    }
    final result = await _get(
      Uri.https('passport.bilibili.com', '/x/passport-login/web/qrcode/poll', {
        'qrcode_key': ticket.key,
      }),
      cancellation: cancellation,
    );
    if (result.data['refresh_token'] != null &&
        result.data['refresh_token'] is! String) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    return switch (result.data['code']) {
      86101 => const BiliQrResult(BiliQrStatus.waiting),
      86090 => const BiliQrResult(BiliQrStatus.scanned),
      86038 => const BiliQrResult(BiliQrStatus.expired),
      0 => BiliQrResult(
        BiliQrStatus.confirmed,
        credentials: credentialsFromCookies(
          result.cookies,
          refreshToken: result.data['refresh_token'] as String?,
          now: _clock(),
        ),
      ),
      _ => throw const ApiFailure(ApiFailureKind.invalidResponse),
    };
  }

  static BiliCredentials credentialsFromCookies(
    List<String> lines, {
    String? refreshToken,
    DateTime? now,
  }) {
    try {
      final values = <String, String>{};
      for (final line in lines) {
        if (line.length > 8192) throw const FormatException();
        final cookie = Cookie.fromSetCookieValue(line);
        if (!BiliCredentials.cookieNames.contains(cookie.name)) continue;
        final domain = cookie.domain
            ?.replaceFirst(RegExp(r'^\.'), '')
            .toLowerCase();
        if (domain != 'bilibili.com' ||
            (cookie.path != null && cookie.path != '/') ||
            (cookie.maxAge != null && cookie.maxAge! <= 0) ||
            (cookie.expires != null &&
                !cookie.expires!.isAfter(now ?? DateTime.now()))) {
          throw const FormatException();
        }
        if (values.containsKey(cookie.name) &&
            values[cookie.name] != cookie.value) {
          throw const FormatException();
        }
        values[cookie.name] = cookie.value;
      }
      return BiliCredentials(
        values,
        refreshToken: refreshToken?.isEmpty == true ? null : refreshToken,
      );
    } catch (_) {
      throw const AccountFailure(AccountFailureKind.invalidCredentials);
    }
  }

  @override
  Future<BiliAccountProfile> verify(
    BiliCredentials credentials, {
    RequestCancellation? cancellation,
  }) async {
    final uri = Uri.https('api.bilibili.com', '/x/web-interface/nav');
    final data = (await _get(
      uri,
      credentials: credentials,
      cancellation: cancellation,
    )).data;
    final rawMid = data['mid'];
    if (data['isLogin'] == false) {
      throw const ApiFailure(ApiFailureKind.loginRequired);
    }
    final mid = rawMid is String
        ? rawMid
        : rawMid is int
        ? '$rawMid'
        : '';
    if (data['isLogin'] != true ||
        mid != credentials.mid ||
        data['uname'] is! String ||
        (data['uname'] as String).trim().isEmpty ||
        (data['uname'] as String).length > 1000) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    final avatar = data['face'] is String
        ? Uri.tryParse(data['face'] as String)
        : null;
    return BiliAccountProfile(
      mid: mid,
      name: data['uname'] as String,
      avatar:
          avatar?.scheme == 'https' &&
              avatar!.host.isNotEmpty &&
              avatar.userInfo.isEmpty &&
              avatar.toString().length <= 4096
          ? avatar
          : null,
    );
  }

  Future<({Map<String, dynamic> data, List<String> cookies})> _get(
    Uri uri, {
    BiliCredentials? credentials,
    RequestCancellation? cancellation,
  }) => _gate.run(() async {
    _check(cancellation);
    final token = CancelToken();
    _requests.add(token);
    cancellation?.onCancel(token.cancel);
    var timedOut = false;
    final timer = Timer(deadline, () {
      timedOut = true;
      token.cancel();
    });
    try {
      final response = await _dio.getUri<ResponseBody>(
        uri,
        cancelToken: token,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
          maxRedirects: 0,
          validateStatus: (_) => true,
          receiveTimeout: const Duration(seconds: 12),
          headers: {
            'User-Agent': BiliMetadataClient.userAgent,
            'Referer': 'https://www.bilibili.com/',
            'Accept': 'application/json',
            if (credentials?.metadataHeader(uri) != null)
              'Cookie': credentials!.metadataHeader(uri)!,
          },
        ),
      );
      _check(cancellation);
      final body = response.data;
      if (body == null) throw const ApiFailure(ApiFailureKind.invalidResponse);
      if (response.statusCode != 200) {
        await body.stream.listen((_) {}).cancel();
        if (response.statusCode == 429) {
          throw ApiFailure(
            ApiFailureKind.rateLimited,
            retryAfter: PublicApiClient.parseRetryAfter(
              response.headers.value('retry-after'),
              now: _clock(),
            ),
          );
        }
        if (response.statusCode == 412) {
          throw const ApiFailure(ApiFailureKind.riskControl);
        }
        throw const ApiFailure(ApiFailureKind.unavailable);
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in body.stream.timeout(
        const Duration(seconds: 12),
      )) {
        _check(cancellation);
        if (bytes.length + chunk.length > 512 * 1024) {
          throw const ApiFailure(ApiFailureKind.invalidResponse);
        }
        bytes.add(chunk);
      }
      _check(cancellation);
      if (timedOut) throw const ApiFailure(ApiFailureKind.timeout);
      final value = jsonDecode(utf8.decode(bytes.takeBytes()));
      if (value is! Map || value['code'] is! int) {
        throw const ApiFailure(ApiFailureKind.invalidResponse);
      }
      if (value['code'] != 0) {
        throw ApiFailure(switch (value['code']) {
          -101 => ApiFailureKind.loginRequired,
          -352 || -412 => ApiFailureKind.riskControl,
          -509 || -799 => ApiFailureKind.rateLimited,
          _ => ApiFailureKind.unavailable,
        });
      }
      final data = value['data'];
      if (data is! Map<String, dynamic>) {
        throw const ApiFailure(ApiFailureKind.invalidResponse);
      }
      if (data['v_voucher'] != null || data['is_risk'] == true) {
        throw const ApiFailure(ApiFailureKind.riskControl);
      }
      return (
        data: data,
        cookies: response.headers['set-cookie'] ?? const <String>[],
      );
    } on ApiFailure {
      rethrow;
    } on AccountFailure {
      rethrow;
    } on TimeoutException {
      throw const ApiFailure(ApiFailureKind.timeout);
    } on DioException catch (error) {
      if (timedOut ||
          [
            DioExceptionType.connectionTimeout,
            DioExceptionType.receiveTimeout,
            DioExceptionType.sendTimeout,
          ].contains(error.type)) {
        throw const ApiFailure(ApiFailureKind.timeout);
      }
      if (error.type == DioExceptionType.cancel) {
        throw const ApiFailure(ApiFailureKind.cancelled);
      }
      throw const ApiFailure(ApiFailureKind.offline);
    } catch (_) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    } finally {
      timer.cancel();
      token.cancel();
      _requests.remove(token);
    }
  });
  void _check(RequestCancellation? cancellation) {
    if (_closed || cancellation?.isCancelled == true) {
      throw const ApiFailure(ApiFailureKind.cancelled);
    }
  }

  void close() {
    _closed = true;
    for (final token in _requests.toList()) {
      token.cancel();
    }
    _requests.clear();
    _dio.close(force: true);
  }
}
