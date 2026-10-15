import 'package:dio/dio.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/public_api_client.dart';
import '../domain/app_release.dart';

/// The app's releases. dynamic_asoul's `app/release` serves a cached copy
/// of the GitHub list, reachable where api.github.com is not and without
/// GitHub's anonymous quota; GitHub itself is asked only when that fails.
class ReleaseSource {
  ReleaseSource(this._api, this._github);
  final PublicApiClient _api;
  final Dio _github;

  static final githubUrl = Uri.parse(
    'https://api.github.com/repos/LEN5010/Asasfans-Next/releases?per_page=20',
  );

  Future<List<AppRelease>> releases() async {
    try {
      return decodeFeed(await _api.get('app/release'));
    } on ApiFailure {
      return _fromGithub();
    }
  }

  Future<List<AppRelease>> _fromGithub() async {
    try {
      final response = await _github.getUri<Object?>(githubUrl);
      return decodeGithub(response.data);
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

  /// dynamic_asoul's list, already without drafts and non-version tags.
  static List<AppRelease> decodeFeed(Map<String, dynamic> body) {
    final releases = body['releases'];
    if (releases is! List) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    return [
      for (final entry in releases)
        if (entry is Map)
          ?_release(
            version: entry['version'],
            title: entry['title'],
            page: entry['page'],
            notes: entry['notes'],
            preRelease: entry['prerelease'],
            published: entry['publishedAt'],
          ),
    ];
  }

  /// GitHub's list: drafts and tags that are not versions are left out.
  static List<AppRelease> decodeGithub(Object? data) {
    if (data is! List) throw const ApiFailure(ApiFailureKind.invalidResponse);
    return [
      for (final entry in data)
        if (entry is Map && entry['draft'] != true)
          ?_release(
            version: entry['tag_name'],
            title: entry['name'],
            page: entry['html_url'],
            notes: entry['body'],
            preRelease: entry['prerelease'],
            published: entry['published_at'],
          ),
    ];
  }

  static AppRelease? _release({
    required Object? version,
    required Object? title,
    required Object? page,
    required Object? notes,
    required Object? preRelease,
    required Object? published,
  }) {
    final parsed = version is String ? AppVersion.tryParse(version) : null;
    final uri = page is String ? Uri.tryParse(page) : null;
    if (parsed == null || uri == null || uri.scheme != 'https') return null;
    return AppRelease(
      version: parsed,
      title: title is String && title.trim().isNotEmpty
          ? title.trim()
          : 'v${parsed.label}',
      page: uri,
      notes: notes is String ? notes.replaceAll('\r\n', '\n').trim() : '',
      preRelease: preRelease == true || parsed.isPreRelease,
      publishedAt: published is String ? DateTime.tryParse(published) : null,
    );
  }
}
