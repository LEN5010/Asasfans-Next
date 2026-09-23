import 'package:dio/dio.dart';

import '../../../core/domain/content_identity.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/public_api_client.dart';
import '../domain/dynamic_repository.dart';

/// Adapter for the public historical-dynamics endpoints.
class DynamicPostRepository implements DynamicRepository {
  DynamicPostRepository(this._api, {required this.baseUrl});
  final PublicApiClient _api;
  final Uri baseUrl;

  @override
  Future<DynamicPage> search({
    DynamicQuery query = const DynamicQuery(),
    String? cursor,
    RequestCancellation? cancellation,
  }) async {
    if (!query.isServerAcceptable) {
      throw const ApiFailure(ApiFailureKind.invalidRequest);
    }
    final token = CancelToken();
    cancellation?.onCancel(token.cancel);
    final json = await _api.get(
      'search',
      query: buildSearchQuery(query, cursor: cursor),
      cancelToken: token,
    );
    return decodeSearch(json, baseUrl: baseUrl);
  }

  @override
  Future<List<DynamicMember>> members() async {
    final json = await _api.get('members');
    final items = json['items'] ?? json['members'];
    if (items is! List) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    return List.unmodifiable(items.map((raw) => _member(raw, baseUrl)));
  }

  static Map<String, dynamic> buildSearchQuery(
    DynamicQuery query, {
    String? cursor,
  }) {
    final keyword = query.keyword.trim();
    return {
      if (keyword.isNotEmpty) 'q': keyword,
      'member': ?query.memberId,
      'type': ?query.type?.name,
      'from': ?_date(query.from),
      'to': ?_date(query.to),
      'sort': query.sort.name,
      'limit': query.limit,
      'cursor': ?cursor,
    };
  }

  /// The range filter is a calendar date, not an instant.
  static String? _date(DateTime? value) => value == null
      ? null
      : '${value.year.toString().padLeft(4, '0')}-'
            '${value.month.toString().padLeft(2, '0')}-'
            '${value.day.toString().padLeft(2, '0')}';

  static DynamicPage decodeSearch(
    Map<String, dynamic> json, {
    required Uri baseUrl,
  }) {
    final items = json['items'];
    final next = json['nextCursor'];
    final prev = json['prevCursor'];
    if (items is! List || !_isCursor(next) || !_isCursor(prev)) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    final total = json['total'];
    return DynamicPage(
      items: List.unmodifiable(items.map((raw) => decodePost(raw, baseUrl))),
      nextCursor: next as String?,
      prevCursor: prev as String?,
      total: total is int && total >= 0 ? total : null,
    );
  }

  static bool _isCursor(Object? value) =>
      value == null || (value is String && value.isNotEmpty);

  @override
  Future<List<DynamicPost>> onThisDay({
    String? monthDay,
    OnThisDaySort sort = OnThisDaySort.hot,
    int limit = 8,
  }) async {
    if (limit < 1 || limit > 20) {
      throw const ApiFailure(ApiFailureKind.invalidRequest);
    }
    if (monthDay != null && !_monthDay.hasMatch(monthDay)) {
      throw const ApiFailure(ApiFailureKind.invalidRequest);
    }
    final json = await _api.get(
      'on-this-day',
      query: {'monthDay': ?monthDay, 'sort': sort.name, 'limit': limit},
    );
    return decodeOnThisDay(json, baseUrl: baseUrl);
  }

  static final _monthDay = RegExp(r'^\d{2}-\d{2}$');

  static List<DynamicPost> decodeOnThisDay(
    Map<String, dynamic> json, {
    required Uri baseUrl,
  }) {
    final items = json['items'];
    if (items is! List) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    return List.unmodifiable(items.map((raw) => decodePost(raw, baseUrl)));
  }

  static DynamicPost decodePost(Object? raw, Uri baseUrl) {
    if (raw is! Map) throw const ApiFailure(ApiFailureKind.invalidResponse);
    // Snowflake ids exceed the safe integer range, so they stay strings.
    final id = raw['dynamicId'];
    if (id is! String || id.isEmpty) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    final member = raw['member'];
    return DynamicPost(
      identity: ContentIdentity(
        source: ContentSource.bilibiliDynamic,
        value: id,
      ),
      member: _member(member, baseUrl),
      type: _type(raw['type']),
      text: _string(raw['contentText']),
      images: _images(raw['images'], baseUrl),
      media: _media(raw['media'], baseUrl),
      publishedAt: _timestamp(raw['publishedAt']),
      sourceUrl: _dynamicUrl(raw['url'], raw['dynamicId'], baseUrl),
      likeCount: _count(raw['likeCount']),
      commentCount: _count(raw['commentCount']),
      forwardCount: _count(raw['forwardCount']),
      forwardedFrom: _forwarded(raw['orig'], baseUrl),
    );
  }

  static DynamicMember _member(Object? raw, Uri baseUrl) {
    if (raw is! Map) {
      return const DynamicMember(id: '', name: '未知成员');
    }
    final id = _string(raw['id']);
    final name = _string(raw['name']);
    return DynamicMember(
      id: id,
      // The source masks this account's name; the app shows her own name.
      name: id == 'uid:3546730823944886'
          ? '来芙Laffey'
          : name.isEmpty
          ? '未知成员'
          : name,
      bilibiliUid: _string(raw['bilibiliUid']),
      avatarUrl: _httpsUri(raw['avatarUrl'], baseUrl),
    );
  }

  static ForwardedPost? _forwarded(Object? raw, Uri baseUrl) {
    if (raw is! Map) return null;
    return ForwardedPost(
      dynamicId: _string(raw['dynamicId']),
      authorMid: _string(raw['authorMid']),
      type: _type(raw['type']),
      // orig.publishedAt is a Unix timestamp in seconds, unlike the post ISO.
      publishedAt: raw['publishedAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(
              (raw['publishedAt'] as int) * 1000,
              isUtc: true,
            )
          : null,
      authorName: _string(raw['authorName']),
      text: _string(raw['text']),
      images: _images(raw['images'], baseUrl),
      media: _media(raw['media'], baseUrl),
      sourceUrl: _dynamicUrl(raw['url'], raw['dynamicId'], baseUrl),
    );
  }

  /// An unknown server type degrades to `other` rather than dropping the post.
  static DynamicType _type(Object? raw) => DynamicType.values.firstWhere(
    (value) => value.name == raw,
    orElse: () => DynamicType.other,
  );

  static List<DynamicMedia> _media(Object? raw, Uri baseUrl) => raw is! List
      ? const []
      : List.unmodifiable([
          for (final entry in raw.whereType<Map<Object?, Object?>>())
            DynamicMedia(
              kind:
                  DynamicMediaKind.values
                      .where((value) => value.name == entry['kind'])
                      .firstOrNull ??
                  DynamicMediaKind.other,
              url: _httpsUri(entry['url'], baseUrl),
              ref: _string(entry['ref']),
              title: _string(entry['title']),
              label: _string(entry['label']),
              description: _string(entry['description']),
              badge: _string(entry['badge']),
              actionText: _string(entry['actionText']),
              durationText: _string(entry['durationText']),
              width: _dimension(entry['width']),
              height: _dimension(entry['height']),
            ),
        ]);

  static int? _dimension(Object? raw) => raw is int && raw > 0 ? raw : null;

  static List<Uri> _images(Object? raw, Uri baseUrl) => List.unmodifiable(
    raw is List
        ? raw.map((item) => _httpsUri(item, baseUrl)).whereType<Uri>()
        : const <Uri>[],
  );

  static String _string(Object? raw) => raw is String ? raw : '';

  static int _count(Object? raw) => raw is int && raw >= 0 ? raw : 0;

  static DateTime? _timestamp(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  static Uri? _dynamicUrl(Object? raw, Object? id, Uri baseUrl) {
    if (raw is String && raw.trim().isNotEmpty) return _httpsUri(raw, baseUrl);
    return id is String && RegExp(r'^\d{1,20}$').hasMatch(id)
        ? Uri.https('t.bilibili.com', '/$id')
        : null;
  }

  static Uri? _httpsUri(Object? raw, Uri baseUrl) {
    if (raw is! String || raw.trim().isEmpty) return null;
    final parsed = Uri.tryParse(raw);
    if (parsed == null) return null;
    var uri = baseUrl.resolveUri(parsed);
    // Historical archive avatars can still use HTTP Bilibili image URLs.
    // Upgrade only the known public CDN path; requests never use cleartext.
    if (uri.scheme == 'http' &&
        uri.path.startsWith('/bfs/') &&
        RegExp(
          r'(^|\.)(hdslb\.com|biliimg\.com)$',
          caseSensitive: false,
        ).hasMatch(uri.host)) {
      uri = uri.replace(scheme: 'https');
    }
    return uri.scheme == 'https' && uri.host.isNotEmpty && uri.userInfo.isEmpty
        ? uri
        : null;
  }
}
