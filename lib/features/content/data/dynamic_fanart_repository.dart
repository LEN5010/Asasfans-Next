import 'package:dio/dio.dart';

import '../../../core/domain/content_identity.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/public_api_client.dart';
import '../domain/fanart_repository.dart';

/// Adapter for the public read-only `dynamic_asoul` fanart dataset.
///
/// The published bot document lags the deployed service, so the wire contract
/// here follows the server's shared DTO. Unknown fields are ignored rather than
/// rejected, and long source identifiers always stay strings.
class DynamicFanartRepository implements FanartRepository {
  DynamicFanartRepository(this._api, {required this.baseUrl});
  final PublicApiClient _api;
  final Uri baseUrl;

  @override
  Future<FanartPage> page({
    FanartQuery query = const FanartQuery(),
    String? cursor,
    RequestCancellation? cancellation,
  }) async {
    if (!query.isServerAcceptable) {
      throw const ApiFailure(ApiFailureKind.invalidRequest);
    }
    final token = CancelToken();
    cancellation?.onCancel(token.cancel);
    final json = await _api.get(
      'fanart',
      query: buildQuery(query, cursor: cursor),
      cancelToken: token,
    );
    return decodePage(json, baseUrl: baseUrl);
  }

  @override
  Future<FanartItem?> random({
    FanartQuery query = const FanartQuery(),
    RequestCancellation? cancellation,
  }) async {
    if (!query.isServerAcceptable) {
      throw const ApiFailure(ApiFailureKind.invalidRequest);
    }
    final token = CancelToken();
    cancellation?.onCancel(token.cancel);
    final json = await _api.get(
      'fanart',
      // The server rejects combining random mode with a cursor.
      query: {...buildQuery(query.copyWith(limit: 1)), 'random': '1'},
      cancelToken: token,
    );
    return decodePage(json, baseUrl: baseUrl).items.firstOrNull;
  }

  /// Only parameters the deployed service validates are sent; an unsupported
  /// value would spend one of the shared 120 requests per minute on a 400.
  static Map<String, dynamic> buildQuery(FanartQuery query, {String? cursor}) {
    final keyword = query.keyword.trim();
    return {
      if (keyword.isNotEmpty) 'q': keyword,
      if (query.characters.isNotEmpty)
        'character': (query.characters.map((c) => c.wire).toList()..sort())
            .join(','),
      'kind': query.kind.name,
      'contentType': query.contentType.name,
      'category': query.category.wire,
      'sort': query.sort.name,
      if (query.source != FanartSource.all) 'source': query.source.name,
      'limit': query.limit,
      'cursor': ?cursor,
    };
  }

  static FanartPage decodePage(
    Map<String, dynamic> json, {
    required Uri baseUrl,
  }) {
    final items = json['items'];
    final snapshot = json['snapshot'];
    final next = json['nextCursor'];
    final prev = json['prevCursor'];
    if (items is! List ||
        snapshot is! Map ||
        snapshot['id'] is! String ||
        (snapshot['id'] as String).isEmpty ||
        !_isCursor(next) ||
        !_isCursor(prev)) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    final total = json['total'];
    return FanartPage(
      items: List.unmodifiable(items.map((raw) => _decodeItem(raw, baseUrl))),
      snapshotId: snapshot['id'] as String,
      nextCursor: next as String?,
      prevCursor: prev as String?,
      total: total is int && total >= 0 ? total : null,
    );
  }

  static bool _isCursor(Object? value) =>
      value == null || (value is String && value.isNotEmpty);

  static FanartItem _decodeItem(Object? raw, Uri baseUrl) {
    if (raw is! Map) throw const ApiFailure(ApiFailureKind.invalidResponse);
    final id = raw['sourceDynamicId'];
    if (id is! String || id.isEmpty) {
      throw const ApiFailure(ApiFailureKind.invalidResponse);
    }
    // Douban topics and Bilibili dynamics share one feed but not one namespace.
    final douban = id.startsWith('douban:');
    final value = douban ? id.substring('douban:'.length) : id;
    if (value.isEmpty) throw const ApiFailure(ApiFailureKind.invalidResponse);
    final images = raw['images'];
    return FanartItem(
      identity: ContentIdentity(
        source: douban
            ? ContentSource.doubanTopic
            : ContentSource.bilibiliDynamic,
        value: value,
      ),
      text: _string(raw['text']),
      authorName: _string(raw['authorName']),
      authorUid: _string(raw['authorUid']),
      kind: _kind(raw['kind']),
      contentType: _contentType(raw['contentType']),
      category: _category(raw['category']),
      characterTags: List.unmodifiable(_characters(raw['characterTags'])),
      sourceUrl: _httpsUri(raw['sourceDynamicUrl'], baseUrl),
      mediaUrl: _httpsUri(raw['mediaUrl'], baseUrl),
      authorAvatarUrl: _httpsUri(raw['authorAvatarUrl'], baseUrl),
      authorSpaceUrl: _httpsUri(raw['authorSpaceUrl'], baseUrl),
      viewCount: _count(raw['viewCount']),
      favoriteCount: _count(raw['favoriteCount']),
      images: List.unmodifiable(
        images is List
            ? images.map((item) => _httpsUri(item, baseUrl)).whereType<Uri>()
            : const <Uri>[],
      ),
    );
  }

  static String _string(Object? raw) => raw is String ? raw : '';

  static int? _count(Object? raw) => raw is int && raw >= 0 ? raw : null;

  /// An unrecognised facet value degrades to the widest bucket instead of
  /// discarding the item, so a new server category never blanks the list.
  static FanartKind _kind(Object? raw) => FanartKind.values
      .where((value) => value != FanartKind.all)
      .firstWhere((value) => value.name == raw, orElse: () => FanartKind.all);

  static FanartContentType _contentType(Object? raw) => FanartContentType.values
      .where((value) => value != FanartContentType.all)
      .firstWhere(
        (value) => value.name == raw,
        orElse: () => FanartContentType.other,
      );

  static FanartCategory _category(Object? raw) => FanartCategory.values
      .where((value) => value != FanartCategory.all)
      .firstWhere(
        (value) => value.wire == raw,
        orElse: () => FanartCategory.normal,
      );

  static List<FanartCharacter> _characters(Object? raw) => raw is! List
      ? const []
      : raw
            .map(
              (tag) => FanartCharacter.values
                  .where((value) => value.wire == tag)
                  .firstOrNull,
            )
            .whereType<FanartCharacter>()
            .toList();

  /// Only absolute HTTPS locations are accepted. Relative frozen-asset paths
  /// resolve against the deployed API base so they keep their route prefix.
  static Uri? _httpsUri(Object? raw, Uri baseUrl) {
    if (raw is! String || raw.trim().isEmpty) return null;
    final parsed = Uri.tryParse(raw);
    if (parsed == null) return null;
    final uri = baseUrl.resolveUri(parsed);
    return uri.scheme == 'https' && uri.host.isNotEmpty && uri.userInfo.isEmpty
        ? uri
        : null;
  }
}
