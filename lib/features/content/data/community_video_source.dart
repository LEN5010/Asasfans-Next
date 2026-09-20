import 'package:dio/dio.dart';

import '../../../core/domain/content_identity.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/public_api_client.dart';
import '../../../core/network/rate_limit_gate.dart';
import '../domain/community_video_repository.dart';

/// Adapter for the community video index.
///
/// The contract was verified against the previous native client: tag, uploader
/// and publish-time conditions work, but title search does not, so a keyword
/// query is refused here rather than silently returning unrelated results.
class CommunityVideoSource implements CommunityVideoRepository {
  CommunityVideoSource(
    this._dio, {
    required this.endpoint,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       _rateLimit = RateLimitGate(clock: clock);

  final Dio _dio;
  final RateLimitGate _rateLimit;
  final Uri endpoint;
  final DateTime Function() _clock;

  static final defaultEndpoint = Uri.parse(
    'https://api.asoul.us.kg/asasfans/v2/asoul-video-interface/advanced-search',
  );

  /// The source returns 20 items per page.
  static const pageSize = 20;

  @override
  Future<CommunityVideoPage> videos({
    CommunityVideoQuery query = const CommunityVideoQuery(),
    int page = 1,
    RequestCancellation? cancellation,
  }) => _rateLimit.run(
    () => _videos(query: query, page: page, cancellation: cancellation),
  );

  Future<CommunityVideoPage> _videos({
    required CommunityVideoQuery query,
    required int page,
    RequestCancellation? cancellation,
  }) async {
    if (page < 1 || page > 100000 || !query.isServerAcceptable) {
      throw const ApiFailure(ApiFailureKind.invalidRequest);
    }
    final token = CancelToken();
    cancellation?.onCancel(token.cancel);
    try {
      final response = await _dio.getUri<Object?>(
        endpoint.replace(
          queryParameters: buildQuery(query, page: page, now: _clock()),
        ),
        cancelToken: token,
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const ApiFailure(ApiFailureKind.invalidResponse);
      }
      return decodePage(data, requestedPage: page);
    } on DioException catch (error) {
      throw _map(error);
    }
  }

  /// Conditions are joined into one expression, so their syntax has to be
  /// produced exactly; the domain refuses tags that would corrupt it.
  static Map<String, String> buildQuery(
    CommunityVideoQuery query, {
    required int page,
    required DateTime now,
  }) {
    final anchor = query.asOf ?? now;
    final conditions = <String>[
      if (query.tags.isNotEmpty)
        'tag.${(query.tags.toSet().toList()..sort()).join('+')}.AND',
      if (query.creatorId != null) 'mid.${query.creatorId}.OR',
      if (query.withinDays != null || query.asOf != null)
        'pubdate.${query.withinDays == null ? 0 : _secondsAgo(anchor, query.withinDays!)}+'
            '${anchor.millisecondsSinceEpoch ~/ 1000}.BETWEEN',
    ];
    return {
      'order': query.order == CommunityVideoOrder.newest ? 'pubdate' : 'score',
      'q': conditions.join('~'),
      // Sent empty because the source ignores them but expects the keys.
      'copyright': '',
      'tname': '',
      'page': '$page',
    };
  }

  static int _secondsAgo(DateTime now, int days) {
    final value = now.millisecondsSinceEpoch ~/ 1000 - days * 86400;
    return value < 0 ? 0 : value;
  }

  static CommunityVideoPage decodePage(
    Map<String, dynamic> json, {
    required int requestedPage,
  }) {
    final data = json['data'];
    if (data is! Map) throw const ApiFailure(ApiFailureKind.invalidResponse);
    final actual = _int(data['page']) ?? requestedPage;
    // A page number that does not match the request means the response
    // belongs to a different query; appending it would corrupt the list.
    if (actual != requestedPage) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    final items = data['result'];
    if (items is! List) throw const ApiFailure(ApiFailureKind.invalidResponse);

    final seen = <String>{};
    final videos = <CommunityVideo>[];
    for (final raw in items) {
      final video = _decodeVideo(raw);
      if (seen.add(video.identity.value)) videos.add(video);
    }
    final total = _int(data['numResults']);
    return CommunityVideoPage(
      videos: List.unmodifiable(videos),
      page: requestedPage,
      total: total != null && total >= 0 ? total : null,
      hasMore: total != null && total >= 0
          ? requestedPage * pageSize < total
          : items.isNotEmpty,
    );
  }

  static CommunityVideo _decodeVideo(Object? raw) {
    if (raw is! Map) throw const ApiFailure(ApiFailureKind.invalidResponse);
    final bvid = _text(raw['bvid']);
    if (bvid.isEmpty) throw const ApiFailure(ApiFailureKind.invalidResponse);
    final title = _text(raw['title']);
    return CommunityVideo(
      identity: ContentIdentity(
        source: ContentSource.bilibiliVideo,
        value: bvid,
      ),
      title: title.isEmpty ? bvid : title,
      creatorName: _text(raw['name']),
      creatorId: _text(raw['mid']),
      coverUrl: _https(_text(raw['pic'])),
      creatorAvatarUrl: _https(_text(raw['face'])),
      description: _text(raw['desc']),
      category: _text(raw['tname']),
      tags: _tags(raw['tag']),
      publishedAt: _seconds(raw['pubdate']),
      duration: _duration(raw['duration']),
      viewCount: _nonNegative(raw['view']),
      likeCount: _nonNegative(raw['like']),
      rankScore: _finiteNumber(raw['score']),
    );
  }

  /// Legacy rows store tags as one comma-separated string.
  static List<String>? _tags(Object? raw) {
    if (raw is! String) return null;
    if (raw.trim().isEmpty) return const [];
    return List.unmodifiable(
      raw
          .replaceAll("'", '')
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toSet(),
    );
  }

  static String _text(Object? raw) =>
      raw is String ? raw : (raw is num ? '$raw' : '');

  static num? _finiteNumber(Object? raw) {
    final value = raw is num ? raw : (raw is String ? num.tryParse(raw) : null);
    return value != null && value.isFinite ? value : null;
  }

  static int? _int(Object? raw) {
    final value = _finiteNumber(raw);
    return value != null && value == value.roundToDouble()
        ? value.toInt()
        : null;
  }

  static int? _nonNegative(Object? raw) {
    final value = _int(raw);
    return value != null && value >= 0 ? value : null;
  }

  static DateTime? _seconds(Object? raw) {
    final value = _int(raw);
    return value != null && value > 0 && value <= 253402300799
        ? DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true)
        : null;
  }

  static Duration? _duration(Object? raw) {
    final value = _int(raw);
    return value != null && value > 0 && value <= 2147483647
        ? Duration(seconds: value)
        : null;
  }

  /// Bilibili CDN links are often protocol-relative or plain http.
  static Uri? _https(String value) {
    if (value.trim().isEmpty) return null;
    final normalised = value.startsWith('//')
        ? 'https:$value'
        : (value.startsWith('http://')
              ? value.replaceFirst('http://', 'https://')
              : value);
    final uri = Uri.tryParse(normalised);
    return uri != null &&
            uri.scheme == 'https' &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty
        ? uri
        : null;
  }

  ApiFailure _map(DioException error) {
    if (error.type == DioExceptionType.cancel) {
      return const ApiFailure(ApiFailureKind.cancelled);
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const ApiFailure(ApiFailureKind.timeout);
    }
    final status = error.response?.statusCode;
    if (status == null) return const ApiFailure(ApiFailureKind.offline);
    if (status == 429) {
      return ApiFailure(
        ApiFailureKind.rateLimited,
        retryAfter: PublicApiClient.parseRetryAfter(
          error.response?.headers.value('retry-after'),
          now: _clock(),
        ),
      );
    }
    if (status >= 500) return const ApiFailure(ApiFailureKind.unavailable);
    return const ApiFailure(ApiFailureKind.invalidRequest);
  }
}
