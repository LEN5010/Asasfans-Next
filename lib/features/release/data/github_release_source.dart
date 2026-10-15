import 'package:dio/dio.dart';

import '../../../core/network/api_failure.dart';
import '../domain/app_release.dart';

/// The app's releases on GitHub: public, read-only, no token.
class GithubReleaseSource {
  GithubReleaseSource(this._dio);
  final Dio _dio;

  static final releasesUrl = Uri.parse(
    'https://api.github.com/repos/LEN5010/Asasfans-Next/releases?per_page=20',
  );

  Future<List<AppRelease>> releases() async {
    try {
      final response = await _dio.getUri<Object?>(releasesUrl);
      return decode(response.data);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      throw ApiFailure(switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout => ApiFailureKind.timeout,
        // GitHub answers an exhausted anonymous quota with 403.
        _ when status == 403 || status == 429 => ApiFailureKind.rateLimited,
        _ when status != null && status >= 500 => ApiFailureKind.unavailable,
        _ when status == null => ApiFailureKind.offline,
        _ => ApiFailureKind.invalidResponse,
      });
    }
  }

  /// Drafts and tags that are not versions are left out.
  static List<AppRelease> decode(Object? data) {
    if (data is! List) throw const ApiFailure(ApiFailureKind.invalidResponse);
    return [
      for (final entry in data)
        if (entry is Map && entry['draft'] != true) ?_release(entry),
    ];
  }

  static AppRelease? _release(Map<dynamic, dynamic> json) {
    final tag = json['tag_name'];
    final page = json['html_url'];
    final version = tag is String ? AppVersion.tryParse(tag) : null;
    final uri = page is String ? Uri.tryParse(page) : null;
    if (version == null || uri == null || uri.scheme != 'https') return null;
    final title = json['name'];
    final notes = json['body'];
    final published = json['published_at'];
    return AppRelease(
      version: version,
      title: title is String && title.trim().isNotEmpty ? title.trim() : '$tag',
      page: uri,
      notes: notes is String ? notes.replaceAll('\r\n', '\n').trim() : '',
      preRelease: json['prerelease'] == true || version.isPreRelease,
      publishedAt: published is String ? DateTime.tryParse(published) : null,
    );
  }
}
