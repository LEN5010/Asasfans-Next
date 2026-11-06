import 'package:dio/dio.dart';
import '../domain/main_account.dart';
import '../../library/data/cloud_collections.dart';
import '../../library/application/content_snapshots.dart';
import '../../content/data/dynamic_post_repository.dart';
import '../../content/data/dynamic_fanart_repository.dart';

abstract interface class MainAccountApi {
  /// [account] is a username or a verified email address.
  Future<MainSession> login(String account, String password);
  Future<MainSession> register(String username, String password);

  /// Sends a code to a new address; replacing a verified one needs [currentPassword].
  Future<void> sendEmailCode(
    String token,
    String email, {
    String? currentPassword,
  });
  Future<String> verifyEmail(String token, String code);
  Future<void> requestPasswordReset(String account);
  Future<void> confirmPasswordReset(
    String account,
    String code,
    String newPassword,
  );
  Future<MainUser> me(String token);
  Future<void> revoke(String token);
  Future<Set<String>> push(String token, List<Map<String, Object?>> ops);
  Future<List<CloudFavorite>> favorites(String token);
}

/// Dedicated first-party transport. Public feeds, feedback and media use their own clients.
class HttpMainAccountApi implements MainAccountApi {
  HttpMainAccountApi(this.dio, this.baseUrl);
  final Dio dio;
  final Uri baseUrl;

  Future<Map<String, dynamic>> _request(
    String path, {
    String? token,
    Map<String, Object?>? body,
    Map<String, Object?>? query,
  }) async {
    try {
      final response = await dio.request<Object?>(
        path,
        data: body,
        queryParameters: query,
        options: Options(
          method: body == null ? 'GET' : 'POST',
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
        ),
      );
      if (response.data is! Map<String, dynamic>) {
        throw const MainAccountFailure('账号服务返回的数据不完整');
      }
      return response.data! as Map<String, dynamic>;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 && token != null) {
        throw const MainAccountFailure('登录已过期，请重新登录', expired: true);
      }
      final data = error.response?.data;
      if (data is Map &&
          data['error'] is String &&
          (error.response?.statusCode ?? 500) < 500) {
        throw MainAccountFailure(data['error'] as String);
      }
      throw const MainAccountFailure('账号服务连接失败，请重试');
    }
  }

  Future<MainSession> _credentials(
    String path,
    Map<String, Object?> data,
  ) async {
    final json = await _request(path, body: {'client_id': 'asasfans', ...data});
    return MainSession(
      json['access_token'] as String,
      MainUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  @override
  Future<MainSession> login(String account, String password) => _credentials(
    'auth/native/login',
    {'username': account, 'password': password},
  );
  @override
  Future<MainSession> register(String username, String password) =>
      _credentials('auth/native/register', {
        'username': username,
        'password': password,
      });
  @override
  Future<void> sendEmailCode(
    String token,
    String email, {
    String? currentPassword,
  }) async {
    await _request(
      'account/email',
      token: token,
      body: {'email': email, 'currentPassword': ?currentPassword},
    );
  }

  @override
  Future<String> verifyEmail(String token, String code) async =>
      (await _request(
            'account/email/verify',
            token: token,
            body: {'code': code},
          ))['email']
          as String;
  @override
  Future<void> requestPasswordReset(String account) async {
    await _request('auth/password-reset/request', body: {'account': account});
  }

  @override
  Future<void> confirmPasswordReset(
    String account,
    String code,
    String newPassword,
  ) async {
    await _request(
      'auth/password-reset/confirm',
      body: {'account': account, 'code': code, 'newPassword': newPassword},
    );
  }

  @override
  Future<MainUser> me(String token) async {
    final json = await _request('auth/me', token: token);
    if (json['user'] == null) {
      throw const MainAccountFailure('登录已过期，请重新登录', expired: true);
    }
    return MainUser.fromJson(json['user'] as Map<String, dynamic>);
  }

  @override
  Future<void> revoke(String token) async {
    await _request('oauth/revoke', token: token, body: {});
  }

  @override
  Future<Set<String>> push(String token, List<Map<String, Object?>> ops) async {
    final json = await _request(
      'favorites/sync',
      token: token,
      body: {'ops': ops},
    );
    return (json['unknown'] as List).cast<String>().toSet();
  }

  @override
  Future<List<CloudFavorite>> favorites(String token) async {
    final result = <CloudFavorite>[];
    String? cursor;
    do {
      final json = await _request(
        'favorites/keys',
        token: token,
        query: {'limit': 100, 'cursor': ?cursor},
      );
      for (final raw in json['items'] as List) {
        final row = raw as Map<String, dynamic>;
        final key = row['key'] as String;
        if (cloudIdentity(key) == null) continue;
        final item = row['item'];
        final snapshot = item == null
            ? null
            : row['target'] == 'dynamic'
            ? ContentSnapshots.dynamic(
                DynamicPostRepository.decodePost(item, baseUrl),
              )
            : ContentSnapshots.fanart(
                DynamicFanartRepository.decodeItem(item, baseUrl),
              );
        if (snapshot != null && cloudKey(snapshot.identity) != key) {
          throw const MainAccountFailure('收藏数据与内容标识不一致');
        }
        result.add(
          CloudFavorite(
            key,
            DateTime.parse(row['addedAt'] as String).millisecondsSinceEpoch,
            snapshot,
          ),
        );
      }
      cursor = json['nextCursor'] as String?;
    } while (cursor != null);
    return result;
  }
}
