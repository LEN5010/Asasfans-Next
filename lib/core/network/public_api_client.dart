import 'package:dio/dio.dart';

import 'api_failure.dart';

/// Public, read-only metadata transport. Credentials and media playback must
/// use separate clients; this client has no cookie jar or request logging.
class PublicApiClient {
  PublicApiClient(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    final relative = Uri.parse(path);
    if (relative.hasScheme ||
        relative.hasAuthority ||
        path.startsWith('/') ||
        relative.pathSegments.any((segment) => segment == '..') ||
        relative.hasQuery ||
        relative.hasFragment) {
      throw const ApiFailure(ApiFailureKind.invalidRequest);
    }
    try {
      final response = await _dio.get<Object?>(
        path,
        queryParameters: query,
        cancelToken: cancelToken,
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const ApiFailure(ApiFailureKind.invalidResponse);
      }
      return data;
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) {
        throw const ApiFailure(ApiFailureKind.cancelled);
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        throw const ApiFailure(ApiFailureKind.timeout);
      }
      final status = error.response?.statusCode;
      if (status == 409) {
        throw ApiFailure(
          ApiFailureKind.datasetChanged,
          code: errorCode(error.response?.data),
        );
      }
      if (status == 429) {
        throw ApiFailure(
          ApiFailureKind.rateLimited,
          retryAfter: parseRetryAfter(
            error.response?.headers.value('retry-after'),
          ),
        );
      }
      if (status != null && status >= 500) {
        throw ApiFailure(
          ApiFailureKind.unavailable,
          code: errorCode(error.response?.data),
        );
      }
      if (status != null && status >= 400) {
        throw const ApiFailure(ApiFailureKind.invalidRequest);
      }
      throw ApiFailure(
        status == null
            ? ApiFailureKind.offline
            : ApiFailureKind.invalidResponse,
      );
    }
  }

  /// Unknown headers do not cause immediate automatic retries.
  static Duration? parseRetryAfter(String? value) {
    final seconds = int.tryParse(value ?? '');
    return seconds != null && seconds >= 0 ? Duration(seconds: seconds) : null;
  }

  /// Reads only the documented `code` discriminator. Server error prose is not
  /// surfaced to users and never enters diagnostics.
  static String? errorCode(Object? body) {
    if (body is! Map) return null;
    final code = body['code'];
    return code is String && code.isNotEmpty ? code : null;
  }
}
